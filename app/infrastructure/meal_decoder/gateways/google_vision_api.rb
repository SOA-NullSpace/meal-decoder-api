# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'base64'

module MealDecoder
  module Gateways
    # Value object for encapsulating text annotation data
    class TextAnnotation
      def self.from_hash(annotation_hash)
        new(annotation_hash.fetch('description', '')) if annotation_hash
      end

      def initialize(text)
        @text = text
      end

      def to_s
        @text.strip
      end
    end

    # The GoogleVisionAPI class provides methods to interact with the Google Vision API for image analysis.
    class GoogleVisionAPI
      BASE_URL = 'https://vision.googleapis.com/v1/images:annotate'

      def initialize(api_key = ENV.fetch('GOOGLE_CLOUD_API_TOKEN', nil))
        @api_key = api_key
      end

      def detect_text(image_path)
        raise Errno::ENOENT, "File not found: #{image_path}" unless File.exist?(image_path)

        response = send_request(image_path)
        parse_text_from_response(response)
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
        Net::HTTP::Post.new(build_uri).tap do |req|
          req.content_type = 'application/json'
          req.body = build_request_body(image_path)
        end
      end

      # :reek:UtilityFunction
      def build_request_body(image_path)
        JSON.dump(
          requests: [{
            image: {
              content: Base64.strict_encode64(File.read(image_path))
            },
            features: [{
              type: 'TEXT_DETECTION'
            }]
          }]
        )
      end

      # :reek:FeatureEnvy
      def parse_text_from_response(response)
        raise "API request failed with status code: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        json_response = JSON.parse(response.body)
        annotations = json_response.dig('responses', 0, 'textAnnotations') || []
        extract_text_from_annotations(annotations)
      end

      # :reek:UtilityFunction
      def extract_text_from_annotations(annotations)
        return '' if annotations.empty?

        TextAnnotation.from_hash(annotations.first).to_s
      end
    end
  end
end
