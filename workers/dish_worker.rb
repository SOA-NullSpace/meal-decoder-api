# frozen_string_literal: true

require_relative '../require_app'
require_app

require 'figaro'
require 'shoryuken'

module MealDecoder
  module Workers
    # Shoryuken worker class to process dish ingredient requests
    class DishWorker
      # Environment variables setup
      Figaro.application = Figaro::Application.new(
        environment: ENV['RACK_ENV'] || 'development',
        path: File.expand_path('config/secrets.yml')
      )
      Figaro.load
      def self.config = Figaro.env

      Shoryuken.sqs_client = Aws::SQS::Client.new(
        access_key_id: config.AWS_ACCESS_KEY_ID,
        secret_access_key: config.AWS_SECRET_ACCESS_KEY,
        region: config.AWS_REGION
      )

      include Shoryuken::Worker

      shoryuken_options queue: 'meal_decoder_queue', auto_delete: true

      def perform(_sqs_msg, request)
        # Parse the request
        dish_request = JSON.parse(request).transform_keys(&:to_sym)

        # Process the dish request
        dish = process_dish_request(dish_request)

        # Store the result
        store_dish_result(dish)
      end

      private

      def process_dish_request(request)
        # Create dish using the existing mapper
        mapper = Mappers::DishMapper.new(
          Gateways::OpenAIAPI.new(App.config.OPENAI_API_KEY)
        )

        mapper.find(request[:dish_name])
      end

      def store_dish_result(dish)
        Repository::For.entity(dish).create(dish)
      rescue StandardError => e
        puts "Error storing dish: #{e.message}"
        raise
      end
    end
  end
end
