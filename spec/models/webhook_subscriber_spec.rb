require 'rails_helper'

RSpec.describe WebhookSubscriber, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:webhook_events) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_presence_of :url }
    it { is_expected.to validate_presence_of :subscriptions }
  end

  describe '#disable!' do
    let(:subscriber) {
      build(:webhook_subscriber, :with_webhook_event)
    }

    it 'sets enabled attribute to false' do
      expect(subscriber.enabled).to be_truthy
      expect(subscriber.disable!).to be_truthy
      expect(subscriber.enabled).to be_falsy
    end
  end
end
