module Api
  module V1
    # İnce controller: kimlik doğrular, gövdeyi EventIngestor'a verir. CSRF yok (ActionController::API).
    class EventsController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods
      include LiveRefresh

      before_action :authenticate_service

      def create
        result = EventIngestor.new(@service).call(payload)
        broadcast_refresh(:alerts) if result.http_status == :accepted
        render json: result.body, status: result.http_status
      end

      private
        def authenticate_service
          @service = authenticate_with_http_token { |token, _options| Service.find_by(integration_key: token) }
          render json: { error: "Geçersiz entegrasyon anahtarı" }, status: :unauthorized unless @service
        end

        def payload
          JSON.parse(request.raw_post, symbolize_names: true)
        rescue JSON::ParserError
          nil
        end
    end
  end
end
