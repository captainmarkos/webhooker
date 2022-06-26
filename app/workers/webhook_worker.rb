require 'http'

class WebhookWorker
  include Sidekiq::Worker

  MAX_RETRIES = 10

  # Set the max number of retries and tell sidekiq not to store failed webhooks
  # in its set of 'dead' jobs. We don't care about dead webhook jobs.
  sidekiq_options retry: MAX_RETRIES, dead: false

  sidekiq_retry_in do |retry_count|
    # Exponential backoff, with a random 30-second to 10-minute 'jitter'
    # added in to help spread out any webhook bursts.
    jitter = rand((30.seconds)..(10.minutes)).to_i

    # Sidekiq's default retry cadence is retry_count ** 4
    (retry_count ** 5) + jitter
  end

  def perform(webhook_event_id)
    webhook_event = WebhookEvent.find(webhook_event_id)
    return if webhook_event.nil?

    subscriber = webhook_event.subscriber
    return unless valid_subscriber?(subscriber, webhook_event.event)

    # send the webhook request to the subscriber
    response = post_request(subscriber, webhook_event)
    clogger.log_activity("POST response status: #{response.status}")
    store_response(webhook_event, response)

    failed_response_handler(webhook_event, response)
  rescue OpenSSL::SSL::SSLError
    handle_ssl_error(webhook_event)
  rescue HTTP::ConnectionError
    handle_connection_error(webhook_event, subscriber)
  rescue HTTP::TimeoutError
    handle_timeout_error(webhook_event)
  end

  private

  def post_request(subscriber, webhook_event)
    # send the webhook request with a 30 second timeout
    HTTP.timeout(30)
        .headers(request_headers)
        .post(
          subscriber.url,
          body: {
            subscriber_id: subscriber.id,
            subscriber_url: subscriber.url,
            event: webhook_event.event,
            payload: webhook_event.payload
          }.to_json
        )
  end

  def store_response(webhook_event, response)
    webhook_event.update!(response: {
      headers: response.headers.to_h,
      code: response.code.to_i,
      body: response.body.to_s
    })
  end

  def request_headers
    {
      'User-Agent' => 'rails_webhooker_system/1.0',
      'Content-Type' => 'application/json'
    }
  end

  def clogger
    @clogger ||= CLogger.new('WebhookWorker.perform')
  end

  def valid_subscriber?(subscriber, event)
    subscriber.present? && subscriber.enabled? && subscriber.subscribed?(event)
  end

  def handle_ssl_error(webhook_event)
    # Since TLS issues may be due to an expired cert, we'll continue retrying
    # since the issue may get resolved within our 3 day retry window.  This
    # may be a good place to send an alert to the endpoint owner.
    webhook_event.update!(response: { error: 'TLS_ERROR' })
    clogger.log_activity('OpenSSL::SSL::SSLError raised')
  end

  def handle_connection_error(webhook_event, subscriber)
    # This error usually means DNS issues. To save us the bandwidth,
    # we're going to disable the endpoint. This would also be a good
    # location to send an alert to the endpoint owner.
    webhook_event.update(response: { error: 'CONNECTION_ERROR' })
    subscriber.disable!
    clogger.log_activity('HTTP::ConnectionError raised')
    clogger.log_activity("WebhookSubscriber id: #{subscriber.id} has been disabled")
  end

  def handle_timeout_error(webhook_event)
    # This error means the webhook endpoint timed out.  We can either
    # raise a failed request error to trigger a retry or leave it
    # as-is and consider timeouts terminal.  We'll do the latter.
    webhook_event.update!(response: { error: 'TIMEOUT_ERROR' })
    clogger.log_activity('HTTP::TimeoutError raised')
  end

  def failed_response_handler(webhook_event, response)
    return if response.status.success?

    subscriber = webhook_event.subscriber
    raise FailedRequestError unless subscriber.url.match?(/\.ngrok\.io/i)

    code = response.code.to_i
    body = response.body.to_s
    clogger.log_activity(
      "FAIL: response code: #{code} body: #{body} " \
      "WebhookEvent id: #{webhook_event.id} " \
      "Subscriber id: #{subscriber.id}"
    )

    if code == 404 && body.match?(/tunnel .+?\.ngrok\.io not found/i)
      # Automatically delete dead ngrok tunnel endpoints. This error likely
      # means that the user forgot to remove their temporary ngrok webhook
      # endpoint, seeing as it no longer exists.
      subscriber.disable! # destroy!
    elsif code == 502
      # The bad gateway error usually means that the tunnel is still open
      # but the local server is no longer responding for any number of
      # reasons. We're going to automatically retry.
      raise FailedRequestError
    elsif code == 504
      # Automatically disable these since the endpoint is likely an ngrok
      # "stable" URL, but it's not currently running. To save bandwidth,
      # we do not want to automatically retry.
      subscriber.disable!
    else
      # Raise a failed request error and let Sidekiq handle retrying.
      raise FailedRequestError
    end
  end
end
