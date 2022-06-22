class AddSubscriptionsToWebhookEndpoints < ActiveRecord::Migration[7.0]
  def change
    add_column :webhook_subscribers, :subscriptions, :jsonb, default: ['*']
  end
end
