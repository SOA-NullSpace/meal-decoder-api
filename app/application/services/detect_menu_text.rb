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

      def call(image_file, translation_options = {})
        puts "\nProcessing text detection request"
        validate_file(image_file)
          .bind { |file| process_image(file, translation_options) }
          .bind { |text| format_text(text) }
      end

      private

      def validate_file(file)
        puts 'Validating image file'
        return Failure('No image file provided') unless file

        validation = @validator.call(FileParamsBuilder.build(file))
        validation.success? ? Success(file) : Failure(validation.errors.messages.join('; '))
      end

      def process_image(file, translation_options)
        text = @gateway.detect_text(file[:tempfile].path, translation_options)
        Success(text)
      rescue StandardError => error
        Failure("Text detection error: #{error.message}")
      end

      def format_text(text)
        return Success([]) if text.nil? || text.empty?

        Success(text)
      rescue StandardError => error
        Failure("Error formatting text: #{error.message}")
      end
    end

    # Builds parameter hash for file validation
    module FileParamsBuilder
      module_function

      def build(file)
        {
          image_file: {
            tempfile: file[:tempfile],
            type: file[:type],
            filename: file[:filename]
          }
        }
      end
    end
  end
end
