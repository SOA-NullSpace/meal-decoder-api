# frozen_string_literal: true

require 'dry/monads'

module MealDecoder
  module Services
    # Service to process image uploads and detect text
    class DetectMenuText
      include Dry::Monads[:result]

      def initialize(validator = Validation::ImageContract.new)
        @validator = validator
      end

      def call(image_file)
        validate_file(image_file)
          .bind { |file| process_image(file) }
      end

      private

      def validate_file(file)
        maybe_validate_file(file)
          .bind { |valid_file| validate_content(valid_file) }
      end

      def maybe_validate_file(file)
        return Failure('No image file provided') unless file

        Success(file)
      end

      def validate_content(file)
        validation_result = @validator.call(file:)
        if validation_result.success?
          Success(file)
        else
          Failure(validation_result.errors.to_h)
        end
      end

      def process_image(file)
        text = api.detect_text(file[:tempfile].path)
        Success(text)
      rescue StandardError => error
        Failure("Text detection error: #{error.message}")
      end

      def api
        @api ||= Gateways::GoogleVisionAPI.new(App.config.GOOGLE_CLOUD_API_TOKEN)
      end
    end
  end
end
