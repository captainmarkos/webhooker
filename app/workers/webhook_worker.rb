require 'http'

class WebhookWorker
  include Sidekiq::Worker

  def perform(webhook_event_id)
    webhook_event = WebhookEvent.find(webhook_event_id)
    return if webhook_event.nil?

    subscriber = webhook_event.webhook_subscriber
    return if subscriber.nil?

    # send the webhook request to the subscriber
    response = post_request(subscriber, webhook_event)
    clogger.log_activity("POST response status: #{response.status}")

    store_response(webhook_event, response)

    # raise failed request error and let Sidekiq handle retrying
    raise FailedRequestError unless response.status.success?
  rescue HTTP::TimeoutError
    # This error means the webhook endpoint timed out.  We can either
    # raise a failed request error to trigger a retry or leave it
    # as-is and consider timeouts terminal.  We'll do the latter.
    webhook_event.update!(response: { error: 'TIMEOUT_ERROR' })
    clogger.log_activity('HTTP::TimeoutError raised')
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
end
