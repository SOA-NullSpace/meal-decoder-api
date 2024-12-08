# frozen_string_literal: true

require_relative '../require_app'
require_app

require 'figaro'
require 'shoryuken'

module MealDecoder
  module Workers
    # Shoryuken worker class to process dish ingredient requests
    class DishWorker
      include Shoryuken::Worker

      shoryuken_options queue: 'meal-decoder-clone-test', auto_delete: true  # Make sure this matches your queue name exactly

      def perform(_sqs_msg, request)
        puts "WORKER: Processing dish request #{request}"
        begin
          # Parse the request
          dish_request = JSON.parse(request).transform_keys(&:to_sym)

          # Process the dish request
          dish = process_dish_request(dish_request)

          # Store the result
          store_dish_result(dish)
          puts "WORKER: Successfully processed dish #{dish.name}"
        rescue StandardError => e
          puts "WORKER ERROR: #{e.message}"
          raise
        end
      end

      private

      def process_dish_request(request)
        mapper = Mappers::DishMapper.new(
          Gateways::OpenAIAPI.new(App.config.OPENAI_API_KEY)
        )

        mapper.find(request[:dish_name])
      end

      def store_dish_result(dish)
        Repository::For.entity(dish).create(dish)
      end
    end
  end
end
