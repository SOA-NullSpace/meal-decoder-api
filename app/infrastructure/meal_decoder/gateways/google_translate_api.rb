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
        return '' if text.nil? || text.empty?

        response = send_request(text, target_language)
        parse_translation_from_response(response)
      rescue StandardError => e
        handle_translation_error(e)
      end

      private

      def send_request(text, target_language)
        uri = build_uri
        request = build_request(text, target_language)

        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end
      end

      def build_uri
        URI.parse("#{BASE_URL}?key=#{@api_key}")
      end

      def build_request(text, target_language)
        Net::HTTP::Post.new(build_uri).tap do |req|
          req.content_type = 'application/json'
          req.body = JSON.dump({
            q: text,
            target: target_language
          })
        end
      end

      def parse_translation_from_response(response)
        raise "API request failed with status code: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        json_response = JSON.parse(response.body)
        json_response.dig('data', 'translations', 0, 'translatedText')
      end

      def handle_translation_error(error)
        case error
        when Net::HTTPServerException
          raise "Translation API error: #{error.message}"
        when JSON::ParserError
          raise 'Invalid response from translation service'
        else
          raise "Translation failed: #{error.message}"
        end
      end
    end
  end
end
