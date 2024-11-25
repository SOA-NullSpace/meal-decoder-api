# frozen_string_literal: true

require 'http'
require 'json'

module MealDecoder
  module Gateways
    # Factory for creating response providers
    class ResponseProviderFactory
      def self.create(api_client)
        ResponseProvider.new(api_client)
      end
    end

    # Handles OpenAI API response retrieval and validation
    class ResponseProvider
      def initialize(api_client)
        @api_client = api_client
      end

      def fetch_response(dish_name)
        @api_client.send_request(dish_name)
      end
    end

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
        @response_provider = ResponseProviderFactory.create(self)
      end

      # Fetches ingredients for a given dish name using the OpenAI API or a test response if set.
      def fetch_ingredients(dish_name)
        response = @response_provider.fetch_response(dish_name)
        ingredients = extract_ingredients_from_response(response)
        validate_ingredients(ingredients, dish_name)
        ingredients
      end

      def send_request(dish_name)
        HTTP.headers(
          'Content-Type'  => 'application/json',
          'Authorization' => "Bearer #{@api_key}"
        ).post(API_URL, json: request_body(dish_name))
      end

      private

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
        response.is_a?(String) ? JSON.parse(response) : JSON.parse(response.body.to_s)
      end

      def handle_response_errors(error)
        return unless error

        raise_appropriate_error(error['message'])
      end

      def raise_appropriate_error(message)
        case message
        when /not found/ then raise 'Dish not found.'
        when /Invalid API key/ then raise 'Invalid API key provided.'
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
