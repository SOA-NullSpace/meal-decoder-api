# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module MealDecoder
  module Gateways
    # Validates text input for translation
    class TextValidator
      def self.valid?(text)
        text && !text.strip.empty?
      end
    end

    # Builds HTTP requests for translation
    class RequestBuilder
      def self.build_uri(api_key)
        URI.parse("#{GoogleTranslateAPI::BASE_URL}?key=#{api_key}")
      end

      def self.build_request(uri, text, target_language)
        request = Net::HTTP::Post.new(uri)
        configure_request(request, text, target_language)
        request
      end

      private_class_method def self.configure_request(request, text, target_language)
        request.content_type = 'application/json'
        request.body = JSON.dump(
          q: text,
          target: target_language
        )
      end
    end

    # Handles HTTP communication
    class HttpClient
      def self.send_request(uri, request)
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end
      end
    end

    # Coordinates translation process by managing API requests and responses
    # Handles the core translation workflow from request building to response parsing
    class TranslationService
      def initialize(api_key)
        @api_key = api_key
      end

      def perform_translation(text, target_language)
        uri = RequestBuilder.build_uri(@api_key)
        request = RequestBuilder.build_request(uri, text, target_language)
        response = HttpClient.send_request(uri, request)
        ResponseParser.parse(response)
      end
    end

    # Main translation API interface
    class GoogleTranslateAPI
      BASE_URL = 'https://translation.googleapis.com/language/translate/v2'

      def initialize(api_key = ENV.fetch('GOOGLE_CLOUD_API_TOKEN', nil))
        @translation_service = TranslationService.new(api_key)
      end

      def translate(text, target_language = 'en')
        return '' unless TextValidator.valid?(text)

        @translation_service.perform_translation(text, target_language)
      rescue StandardError => error
        ErrorHandler.handle_error(error)
      end
    end
  end
end
