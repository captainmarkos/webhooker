class WebhookSubscriber < ApplicationRecord
  has_many :webhook_events

  validates :name, presence: true
  validates :url, presence: true
  validates :subscriptions, length: { minimum: 1 }, presence: true

  scope :enabled, -> { where(enabled: true) }

  def subscribed?(event)
    (subscriptions & ['*', event]).any?
  end

  #def url
  #  webhooks_url || url
  #end

  def disable!
    update!(enabled: false)
  end

  private

  def webhooks_url
    if Rails.env.development?
      if ENV['WEBHOOKS_HOST'].present?
        "https://#{ENV['WEBHOOKS_HOST']}/api/v1/webhooks"
      else
        'http://localhost:3300/api/v1/webhooks'
      end
    end
  end
end
