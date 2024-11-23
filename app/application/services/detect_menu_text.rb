# frozen_string_literal: true

require 'dry/transaction'

module MealDecoder
  module Service
    # Service to process menu image uploads and detect text
    class DetectMenuText
      include Dry::Transaction

      step :validate_image
      step :detect_text

      private

      def validate_image(input)
        request = Request::Image.new.call(input)
        if request.success?
          Success(input)
        else
          Failure(Response::ApiResult.new(
            status: :cannot_process,
            message: request.errors.full_messages.join('; ')
          ))
        end
      end

      def detect_text(input)
        api = Gateways::GoogleVisionAPI.new(App.config.GOOGLE_CLOUD_API_TOKEN)
        text_result = api.detect_text(input[:image_file][:tempfile].path)
        Success(Response::ApiResult.new(
          status: :ok,
          message: 'Text detected successfully',
          data: text_result
        ))
      rescue StandardError => error
        Failure(Response::ApiResult.new(
          status: :internal_error,
          message: error.message
        ))
      end
    end
  end
end
