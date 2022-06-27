require 'rails_helper'

RSpec.describe CLogger do
  subject(:clogger) { described_class.new }

  let(:logger) { Rails.logger }

  describe '#log_activity' do
    context 'when info message is logged' do
      let(:log_msg) { 'Hello woohoo' }

      before { allow(logger).to receive(:info).and_call_original }

      it 'logs an info message' do
        #expect(logger).to have_received(:info).with(log_msg)
      end
    end

    #context 'when error message is logged' do
    #  it 'logs an error message' do
    #  end
    #end
  end
end
