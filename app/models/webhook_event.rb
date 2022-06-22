class WebhookEvent < ApplicationRecord
  belongs_to :webhook_subscriber

  validates :event, presence: true
  validates :payload, presence: true
end
