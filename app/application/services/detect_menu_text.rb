# frozen_string_literal: true

require 'dry/monads'

# app/application/services/detect_menu_text.rb
module MealDecoder
  module Services
    class DetectMenuText
      include Dry::Monads[:result]

      def initialize
        @validator = Request::Image.new
        @gateway = Gateways::GoogleVisionAPI.new(App.config.GOOGLE_CLOUD_API_TOKEN)
      end

      def call(image_file)
        puts "\nProcessing text detection request"
        validate_file(image_file)
          .bind { |file| process_image(file) }
          .bind { |text| format_text(text) }
      end

      private

      def validate_file(file)
        puts 'Validating image file'
        return Failure('No image file provided') unless file

        validation = @validator.call(image_file: {
                                       tempfile: file[:tempfile],
                                       type: file[:type],
                                       filename: file[:filename]
                                     })

        if validation.success?
          puts 'File validation successful'
          Success(file)
        else
          puts "File validation failed: #{validation.errors.messages}"
          Failure(validation.errors.messages.join('; '))
        end
      end

      # app/services/detect_menu_text.rb
      def process_image(file)
        puts "Processing image: #{file[:filename]}"
        result = @gateway.detect_text(file[:tempfile].path)

        if result['success']
          puts 'Text detection successful'
          Success(result['text'])
        else
          puts "Text detection failed: #{result['message']}"
          Failure(result['message'])
        end
      rescue StandardError => e
        puts "Error in process_image: #{e.class} - #{e.message}"
        puts e.backtrace
        Failure("Text detection error: #{e.message}")
      end

      def format_text(text)
        puts 'Formatting detected text'
        return Success([]) if text.nil? || text.empty?

        lines = text.split("\n")
          .map(&:strip)
          .reject(&:empty?)
          .uniq

        puts "Formatted #{lines.count} lines of text"
        Success(lines)
      rescue StandardError => e
        puts "Error formatting text: #{e.class} - #{e.message}"
        puts e.backtrace
        Failure("Error formatting text: #{e.message}")
      end
    end
  end
end
