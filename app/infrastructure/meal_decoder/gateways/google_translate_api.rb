# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module MealDecoder
  module Gateways
    # Handles translation requests to Google Cloud Translation API
    class GoogleTranslateAPI
      BASE_URL = 'https://translation.googleapis.com/language/translate/v2'

      def initialize(api_key = ENV.fetch('GOOGLE_CLOUD_API_TOKEN', nil))
        @api_key = api_key
      end

      def translate(text, target_language = 'en')
        return '' if text.blank?

        response = TranslationRequestSender.new(@api_key).send_request(text, target_language)
        ResponseParser.parse(response)
      rescue StandardError => error
        ErrorHandler.handle_error(error)
      end
    end

    # Handles sending translation requests
    class TranslationRequestSender
      def initialize(api_key)
        @api_key = api_key
        @http_client = HttpClient.new
      end

      def send_request(text, target_language)
        request = TranslationRequestBuilder.new(text, target_language, @api_key).build
        @http_client.send(request)
      end
    end

    # Manages HTTP communication
    class HttpRequestExecutor
      def self.execute(request)
        uri = URI.parse(request.path)
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end
      end
    end

    # Builds translation request objects
    class TranslationRequestBuilder
      def initialize(text, target_language, api_key)
        @text = text
        @target_language = target_language
        @api_key = api_key
        @request_path = "#{GoogleTranslateAPI::BASE_URL}?key=#{@api_key}"
      end

      def build
        request = Net::HTTP::Post.new(@request_path)
        configure_request(request)
        request
      end

      private

      def configure_request(request)
        request.content_type = 'application/json'
        request.body = JSON.dump(
          q: @text,
          target: @target_language
        )
      end
    end

    # Parses translation API responses
    class ResponseParser
      def self.parse(response)
        new(response).parse
      end

      def initialize(response)
        @response = response
      end

      def parse
        validate_response
        extract_translation
      end

      private

      def validate_response
        raise "API request failed with status code: #{@response.code}" unless @response.is_a?(Net::HTTPSuccess)
      end

      def extract_translation
        json_response = JSON.parse(@response.body)
        json_response.dig('data', 'translations', 0, 'translatedText')
      end
    end

    # Handles translation errors
    class ErrorHandler
      def self.handle_error(error)
        message = build_error_message(error)
        raise message
      end

      def self.build_error_message(error)
        error_info = extract_error_info(error)
        format_error_message(error_info)
      end

      def self.extract_error_info(error)
        {
          type: error.class,
          message: error.message
        }
      end

      def self.format_error_message(error_info)
        message = error_info[:message]
        case error_info[:type]
        when Net::HTTPClientException then "Translation API error: #{message}"
        when JSON::ParserError then 'Invalid response from translation service'
        else "Translation failed: #{message}"
        end
      end

      private_class_method :extract_error_info, :format_error_message
    end
  end
end
