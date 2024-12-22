# app/infrastructure/meal_decoder/gateways/google_vision_api.rb
# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'base64'

module MealDecoder
  module Gateways
    # Value object for encapsulating text annotation data
    class TextAnnotation
      attr_reader :text, :translation

      def self.from_hash(annotation_hash, translation = nil)
        new(annotation_hash.fetch('description', ''), translation) if annotation_hash
      end

      def initialize(text, translation = nil)
        @text = text
        @translation = translation
      end

      def to_h
        return { detected_text: @text.strip } unless @translation

        { detected_text: @text.strip, translated: @translation }
      end

      def to_s
        @text.strip
      end
    end

    # The GoogleVisionAPI class provides methods to interact with the Google Vision API for image analysis.
    class GoogleVisionAPI
      BASE_URL = 'https://vision.googleapis.com/v1/images:annotate'

      def initialize(api_key)
        @api_key = api_key
      end

      def detect_text(image_path, translate: false)
        raise Errno::ENOENT, "File not found: #{image_path}" unless File.exist?(image_path)

        response = send_request(image_path)
        text_results = parse_text_from_response(response)
        translate ? translate_results(text_results) : format_results(text_results)
      end

      private

      def send_request(image_path)
        uri = URI.parse("#{BASE_URL}?key=#{@api_key}")
        request = build_request(image_path)
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
      end

      def build_request(image_path)
        request = Net::HTTP::Post.new(URI.parse("#{BASE_URL}?key=#{@api_key}"))
        request.content_type = 'application/json'
        request.body = JSON.dump({
                                   requests: [{
                                     image: { content: Base64.strict_encode64(File.read(image_path)) },
                                     features: [{ type: 'TEXT_DETECTION', maxResults: 50 }],
                                     imageContext: { languageHints: %w[en zh-TW zh-CN] }
                                   }]
                                 })
        request
      end

      def parse_text_from_response(response)
        raise "API request failed with status code: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        json_response = JSON.parse(response.body)
        return [] if json_response['responses'].empty?

        annotations = json_response['responses'].first['textAnnotations']
        annotations ? extract_text_from_annotations(annotations) : []
      end

      def extract_text_from_annotations(annotations)
        return [] if annotations.empty?

        # Take the first annotation which contains the full text
        text = annotations[0]['description']
        # Split by newlines and clean up
        text.split("\n")
          .map(&:strip)
          .reject(&:empty?)
      end

      def format_results(text_results)
        text_results.map { |text| { detected_text: text } }
      end

      def translate_results(text_results)
        translator = GoogleTranslateAPI.new(@api_key)
        text_results.map do |text|
          {
            detected_text: text,
            translated: translator.translate(text)
          }
        end
      rescue StandardError => e
        puts "Translation error: #{e.message}"
        format_results(text_results)
      end
    end
  end
end
