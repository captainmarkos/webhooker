require 'rails_helper'

RSpec.describe WebhookEvent, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:webhook_subscriber) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of :event }
    it { is_expected.to validate_presence_of :payload }
  end
end
