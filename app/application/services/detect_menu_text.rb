# frozen_string_literal: true

require 'dry/monads'

module MealDecoder
  module Services
    # Service for detecting and processing text from menu images
    # Handles image validation, text detection, and optional translation
    class DetectMenuText
      include Dry::Monads[:result]

      def initialize
        @validator = Request::Image.new
        @gateway = Gateways::GoogleVisionAPI.new(App.config.GOOGLE_CLOUD_API_TOKEN)
      end

      def call(image_file, translate: false)
        puts "\nProcessing text detection request"
        validate_file(image_file)
          .bind { |file| process_image(file, translate) }
          .bind { |text| format_text(text) }
      end

      private

      def validate_file(file)
        puts 'Validating image file'
        return Failure('No image file provided') unless file

        perform_validation(file)
      end

      def perform_validation(file)
        validation = @validator.call(build_validation_params(file))
        validation.success? ? Success(file) : Failure(validation.errors.messages.join('; '))
      end

      def build_validation_params(file)
        {
          image_file: {
            tempfile: file[:tempfile],
            type: file[:type],
            filename: file[:filename]
          }
        }
      end

      def process_image(file, translate)
        text = @gateway.detect_text(file[:tempfile].path, translate:)
        Success(text)
      rescue StandardError => error
        Failure("Text detection error: #{error.message}")
      end

      def format_text(text)
        return Success([]) if text.nil? || text.empty?

        Success(text)
      rescue StandardError => e
        Failure("Error formatting text: #{e.message}")
      end
    end
  end
end
