# app/infrastructure/meal_decoder/gateways/google_vision_api.rb
# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'base64'

module MealDecoder
  module Gateways
    class GoogleVisionAPI
      BASE_URL = 'https://vision.googleapis.com/v1/images:annotate'

      def initialize(api_key = ENV.fetch('GOOGLE_CLOUD_API_TOKEN', nil))
        @api_key = api_key
      end

      def detect_text(image_path)
        raise Errno::ENOENT, "File not found: #{image_path}" unless File.exist?(image_path)

        response = send_request(image_path)
        parsed_response = handle_response(response)

        {
          'success' => true,
          'text'    => parsed_response,
          'message' => 'Text detection successful'
        }
      rescue StandardError => e
        puts "Vision API Error: #{e.message}"
        puts e.backtrace
        {
          'success' => false,
          'text'    => nil,
          'message' => "Vision API Error: #{e.message}"
        }
      end

      private

      def send_request(image_path)
        uri = build_uri
        request = build_request(image_path)

        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end
      end

      def build_uri
        URI.parse("#{BASE_URL}?key=#{@api_key}")
      end

      def build_request(image_path)
        request = Net::HTTP::Post.new(build_uri)
        request.content_type = 'application/json'
        request.body = JSON.dump(build_request_body(image_path))
        request
      end

      def build_request_body(image_path)
        {
          requests: [{
            image: {
              content: Base64.strict_encode64(File.read(image_path))
            },
            features: [{
              type: 'TEXT_DETECTION',
              maxResults: 50
            }],
            imageContext: {
              languageHints: %w[en zh-TW zh-CN]
            }
          }]
        }
      end

      def handle_response(response)
        unless response.is_a?(Net::HTTPSuccess)
          handle_error_response(response)
          return nil
        end

        parse_success_response(response)
      end

      def handle_error_response(response)
        error_message = case response.code
                        when '400' then 'Bad Request: Invalid image format or size'
                        when '401' then 'Unauthorized: Invalid API key'
                        when '403' then 'Forbidden: API key lacks required permissions'
                        else "API request failed with status code: #{response.code}"
                        end
        raise error_message
      end

      def parse_success_response(response)
        json_response = JSON.parse(response.body)
        extract_text_from_response(json_response)
      end

      def extract_text_from_response(json_response)
        text_annotations = json_response.dig('responses', 0, 'textAnnotations')
        return '' if text_annotations.nil? || text_annotations.empty?

        text_annotations.first['description'].strip
      end
    end
  end
end
