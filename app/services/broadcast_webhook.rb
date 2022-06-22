class BroadcastWebhook
  def self.call(event:, payload:)
    new(event: event, payload: payload).call
  end

  def call
    WebhookSubscriber.find_each do |subscriber|
      webhook_event = WebhookEvent.create!(
        webhook_subscriber: subscriber,
        event: event,
        payload: payload
      )

      WebhookWorker.perform_async(webhook_event.id)
    end
  end

  private

  attr_reader :event, :payload

  def initialize(event:, payload:)
    @event = event
    @payload = payload
  end
end
