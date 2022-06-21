class WebhookSubscriber < ApplicationRecord
  has_many :webhook_events

  validates :url, presence: true

  def url
    webhooks_url || url
  end

  def webhooks_url
    if Rails.env.development?
      if ENV['WEBHOOKS_HOST'].present?
        "https://#{ENV['WEBHOOKS_HOST']}/api/v1/webhooks"
      else
        'http://localhost:3000/api/v1/webhooks'
      end
    end
  end
end
