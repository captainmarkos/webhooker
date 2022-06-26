FactoryBot.define do
  factory :webhook_subscriber do
    name { Faker::Name.name }
    url { Faker::Internet.url }
    subscriptions { ["*"] }
    enabled { true }

    trait :with_webhook_event do
      after(:build) do |subscriber|
        subscriber.webhook_events << build(:webhook_event)
      end
    end
  end
end
