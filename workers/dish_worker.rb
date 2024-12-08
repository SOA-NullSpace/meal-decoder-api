# frozen_string_literal: true

require_relative '../require_app'
require_app

require 'figaro'
require 'shoryuken'

module MealDecoder
  module Workers
    # Processes dish requests and manages their lifecycle
    # Handles creation, processing, and storage of dish data
    class DishProcessor
      def initialize(api_key = App.config.OPENAI_API_KEY)
        @mapper = Mappers::DishMapper.new(
          Gateways::OpenAIAPI.new(api_key)
        )
      end

      def process_request(request)
        dish_request = JSON.parse(request).transform_keys(&:to_sym)
        dish = process(dish_request[:dish_name])
        store_dish(dish)
        dish
      end

      private

      def process(dish_name)
        @mapper.find(dish_name)
      end

      def store_dish(dish)
        Repository::For.entity(dish).create(dish)
      rescue StandardError => processing_error
        puts "PROCESSOR: Error storing dish: #{processing_error.message}"
        raise
      end
    end

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

      shoryuken_options queue: ENV.fetch('CLONE_QUEUE', nil), auto_delete: true

      def initialize
        super
        @processor = DishProcessor.new
      end

      def perform(_sqs_msg, request)
        puts "WORKER: Processing dish request #{request}"
        dish = @processor.process_request(request)
        puts "WORKER: Dish stored #{dish.name}"
      end
    end
  end
end
