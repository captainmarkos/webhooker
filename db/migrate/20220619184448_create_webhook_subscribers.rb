class CreateWebhookSubscribers < ActiveRecord::Migration[7.0]
  def change
    create_table :webhook_subscribers do |t|
      t.string :name, default: 'anonymous', null: false
      t.string :url, null: false
      t.json :subscriptions, default: ['*']
      t.boolean :enabled, default: true, null: false, index: true

      t.timestamps
    end
  end
end
