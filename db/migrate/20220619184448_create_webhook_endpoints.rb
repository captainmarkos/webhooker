class CreateWebhookEndpoints < ActiveRecord::Migration[7.0]
  def change
    create_table :webhook_endpoints do |t|
      t.string :url, null: false

      t.timestamps
    end
  end
end
