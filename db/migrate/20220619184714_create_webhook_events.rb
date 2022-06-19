class CreateWebhookEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :webhook_events do |t|
      t.references :webhook_endpoint, null: false
      t.string :event, null: false
      t.text :payload, null: false

      t.timestamps
    end
  end
end
