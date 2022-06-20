module Api
  module V1
    class WebhooksController < ApiBaseController
      #before_action :set_event, only: [:process]

      def process_webhook
        render json: permitted_params[:payload]
      end

      private

      def set_event
        @webhook_event = WebhookEvent.find()
      end

      def permitted_params
        params.require(:webhook).permit(
          :subscriber_id, :subscriber_url, :event, :payload
       )
      end
    end
  end
end
