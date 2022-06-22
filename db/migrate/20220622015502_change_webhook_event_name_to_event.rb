class ChangeWebhookEventNameToEvent < ActiveRecord::Migration[7.0]
  def change
    rename_column :webhook_events, :name, :event
  end
end
