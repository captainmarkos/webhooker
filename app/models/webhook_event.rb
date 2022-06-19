class WebhookEvent < ApplicationRecord
  belongs_to :webhook_subscriber

  validates :name, presence: true
  validates :payload, presence: true
end
