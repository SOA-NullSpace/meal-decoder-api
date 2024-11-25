# frozen_string_literal: true

require 'http'
require 'json'

module MealDecoder
  module Gateways
    # The OpenAIAPI class is responsible for interfacing with the OpenAI API to fetch ingredients for dishes.
    class OpenAIAPI
      API_URL = 'https://api.openai.com/v1/chat/completions'
      UNKNOWN_DISH_PHRASES = [
        "I'm not sure", "I don't have information", "I'm not familiar with",
        "I don't know", 'Unable to provide ingredients', 'not a recognized dish',
        "doesn't appear to be a specific dish", "I don't have enough information",
        "It's unclear what dish you're referring to",
        "I'm sorry, but I can't provide information"
      ].freeze

      SYSTEM_PROMPT = 'You are a helpful assistant that lists ingredients. Provide only ' \
                      'the ingredient names, one per line. Do not include measurements, ' \
                      'numbers, or any other text. If you do not know the dish, say so directly.'

      # Error raised when the API response indicates an unknown dish
      class UnknownDishError < StandardError; end

      # Initializes the OpenAIAPI with an API key.
      def initialize(api_key)
        @api_key = api_key
        @mock_response = nil
      end

      # Fetches ingredients for a given dish name using the OpenAI API or a test response if set.
      def fetch_ingredients(dish_name)
        response = @mock_response || send_request(dish_name)
        ingredients = extract_ingredients_from_response(response)
        validate_ingredients(ingredients, dish_name)
        ingredients
      end

      # For testing purposes only
      def self.with_mock_response(api_key, mock_response)
        new(api_key).tap do |api|
          api.instance_variable_set(:@mock_response, mock_response)
        end
      end

      private

      def send_request(dish_name)
        response = HTTP.headers(
          'Content-Type'  => 'application/json',
          'Authorization' => "Bearer #{@api_key}"
        ).post(API_URL, json: request_body(dish_name))

        response.body.to_s
      rescue HTTP::Error => error
        handle_http_error(error)
      end

      def handle_http_error(error)
        error_text = error.message
        case error_text
        when /401/, /unauthorized/i
          raise "Incorrect API key provided: #{@api_key}"
        else
          raise "HTTP Error: #{error_text}"
        end
      end

      def request_body(dish_name)
        {
          model: 'gpt-4',
          messages: build_messages(dish_name),
          temperature: 0.7
        }
      end

      def build_messages(dish_name)
        [
          {
            role: 'system',
            content: SYSTEM_PROMPT
          },
          {
            role: 'user',
            content: "List the ingredients in #{dish_name}, providing only the ingredient names:"
          }
        ]
      end

      def extract_ingredients_from_response(response)
        body = parse_response_body(response)
        handle_response_errors(body['error'])
        body['choices'].first['message']['content'].strip
      end

      # :reek:UtilityFunction
      def parse_response_body(response)
        JSON.parse(response)
      rescue JSON::ParserError
        raise "Invalid JSON response: #{response}"
      end

      def handle_response_errors(error)
        return unless error

        raise_appropriate_error(error['message'])
      end

      def raise_appropriate_error(message)
        case message
        when /not found/i then raise 'Dish not found.'
        when /incorrect.+key/i then raise "Incorrect API key provided: #{@api_key}"
        else raise "API error: #{message}"
        end
      end

      def validate_ingredients(ingredients, dish_name)
        raise UnknownDishError, "Unknown dish: #{dish_name}" if unknown_dish?(ingredients)
      end

      # :reek:UtilityFunction
      def unknown_dish?(ingredients)
        UNKNOWN_DISH_PHRASES.any? { |phrase| ingredients.downcase.include?(phrase.downcase) }
      end
    end
  end
end
