FactoryBot.define do
  factory :webhook_event do
    event { Faker::Name.name }
    payload { 'data' }
  end
end
