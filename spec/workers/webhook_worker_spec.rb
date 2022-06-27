require 'rails_helper'

RSpec.describe WebhookWorker, type: :worker do
  subject(:worker) { described_class.new }

  #let(:logger) { Rails.logger }

  describe '#perform' do
    let(:webhook_event) {
      create(:webhook_event, webhook_subscriber: subscriber)
    }

    context 'when webhook event is does not exist' do
      it 'raises exception' do
        expect { worker.perform(nil) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when subscriber is valid' do
      let(:subscriber) { create(:webhook_subscriber, enabled: true) }
      let(:response) {
        double(
          headers: [['berp', 'merp']],
          status: double(success?: true),
          code: 200,
          body: 'test'
        )
      }

      #let(:log_msg) { 'Hello woohoo' }
      #before { allow(logger).to receive(:info).and_call_original }

      it 'posts the request to the subscriber' do
        expect(worker).to receive(:post_request).and_return(response)
        worker.perform(webhook_event.id)

        webhook_event.reload

        expect(webhook_event.response['headers']).to eq response.headers.to_h
        expect(webhook_event.response['code']).to eq response.code
        expect(webhook_event.response['body']).to eq response.body
      end
    end



    context 'when subscriber is disabled' do
      let(:subscriber) { create(:webhook_subscriber, enabled: false) }
      it '' do
        expect(worker).not_to receive(:post_request)
        worker.perform(webhook_event.id)
      end
    end
  end
end
