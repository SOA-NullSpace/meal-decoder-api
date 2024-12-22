# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'base64'

module MealDecoder
  module Gateways
    # Encapsulates text annotation data with optional translation support
    class TextAnnotation
      attr_reader :text, :translation

      def self.from_hash(annotation_hash, translation = nil)
        new(annotation_hash.fetch('description', ''), translation) if annotation_hash
      end

      def initialize(text, translation = nil)
        @text = text.strip
        @translation = translation
      end

      def to_h
        return { detected_text: @text } unless @translation

        { detected_text: @text, translated: @translation }
      end

      def to_s
        @text
      end
    end

    # Wraps JSON response data and provides structured access to annotations
    class ResponseData
      def initialize(json_response)
        @json_response = json_response
        @responses = json_response['responses']
      end

      def annotations
        return [] if @responses.empty?

        @responses.first['textAnnotations']
      end

      def empty?
        @responses.empty?
      end
    end

    # Handles parsing and validation of Vision API responses
    class VisionResponseParser
      def self.parse(response)
        new(response).parse
      end

      def initialize(response)
        @response = response
        @response_data = nil
      end

      def parse
        validate_response
        process_json_response
        process_annotations
      end

      private

      def validate_response
        raise "API request failed with status code: #{@response.code}" unless @response.is_a?(Net::HTTPSuccess)
      end

      def process_json_response
        json = JSON.parse(@response.body)
        @response_data = ResponseData.new(json)
        raise 'Empty response' if @response_data.empty?
      end

      def process_annotations
        annotations = @response_data.annotations
        return [] unless annotations&.any?

        text = annotations[0]['description']
        text.split("\n")
          .map(&:strip)
          .reject(&:empty?)
      end
    end

    # Handles HTTP request header formatting
    class RequestFormatter
      def self.format_headers(request)
        request.content_type = 'application/json'
      end
    end

    # Manages HTTP communication with external services
    class HttpClient
      def self.send_request(uri, request)
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end
      end
    end

    # Formats text detection results into consistent response structures
    class ResultFormatter
      def self.format_basic_results(text_results)
        text_results.map { |text| { detected_text: text } }
      end
    end

    # Builds and configures Vision API requests
    class VisionRequestBuilder
      def self.build(image_path, api_key)
        new(image_path, api_key).build
      end

      def initialize(image_path, api_key)
        @image_path = image_path
        @api_key = api_key
      end

      def build
        request = create_request
        RequestFormatter.format_headers(request)
        write_body(request)
        request
      end

      private

      def create_request
        Net::HTTP::Post.new(build_uri)
      end

      def build_uri
        URI.parse("#{GoogleVisionAPI::BASE_URL}?key=#{@api_key}")
      end

      def write_body(request)
        request.body = JSON.dump({
                                   requests: [{
                                     image: { content: encode_image },
                                     features: [{ type: 'TEXT_DETECTION', maxResults: 50 }],
                                     imageContext: { languageHints: %w[en zh-TW zh-CN] }
                                   }]
                                 })
      end

      def encode_image
        Base64.strict_encode64(File.read(@image_path))
      end
    end

    # Provides interface to Google Cloud Vision API for text detection in images
    # with optional translation support. Handles image validation, processing,
    # and result formatting.
    class GoogleVisionAPI
      BASE_URL = 'https://vision.googleapis.com/v1/images:annotate'

      def initialize(api_key)
        @api_key = api_key
        @logger = Logger.new($stdout)
      end

      def detect_text(image_path, translation_options = { enabled: false })
        validate_file(image_path)
        text_results = process_image(image_path)
        format_output(text_results, translation_options)
      end

      private

      def validate_file(image_path)
        raise Errno::ENOENT, "File not found: #{image_path}" unless File.exist?(image_path)
      end

      def process_image(image_path)
        request = VisionRequestBuilder.build(image_path, @api_key)
        uri = URI.parse("#{BASE_URL}?key=#{@api_key}")
        response = HttpClient.send_request(uri, request)
        VisionResponseParser.parse(response)
      end

      def format_output(text_results, translation_options)
        return ResultFormatter.format_basic_results(text_results) unless translation_options[:translate]

        translate_text_results(text_results)
      rescue StandardError => error
        handle_translation_error(error, text_results)
      end

      def translate_text_results(text_results)
        translator = GoogleTranslateAPI.new(@api_key)
        text_results.map do |text|
          {
            detected_text: text,
            translated: translator.translate(text)
          }
        end
      end

      def handle_translation_error(error, text_results)
        @logger.error("Translation error: #{error.message}")
        ResultFormatter.format_basic_results(text_results)
      end
    end
  end
end
