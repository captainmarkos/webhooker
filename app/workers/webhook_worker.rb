require 'http'

class WebhookWorker
  include Sidekiq::Worker

  def perform(event_id)
    event = WebhookEvent.find(event_id)
    return if event.nil? # log

    subscriber = event.webhook_subscriber
    return if subscriber.nil? # log

    # send the webhook request
binding.pry
    response = post_request(subscriber, event)
    clogger.log_activity("POST response status: #{response.status}")

    # raise a failed request error and let sidekiq handle retrying
    raise FailedRequestError unless response.status.success?
  end

  private

  def post_request(subscriber, event)
    # send the webhook request with a 30 second timeout
     HTTP.timeout(30)
         .headers(request_headers)
         .post(
           subscriber.url,
           body: {
             event: event.name,
             payload: event.payload
           }.to_json
         )
  end

  def request_headers
    {
      'User-Agent' => 'rails_webhook_system/1.0',
      'Content-Type' => 'application/json'
    }
  end

  def clogger
    @clogger ||= CLogger.new('WebhookWorker.perform')
  end
end
