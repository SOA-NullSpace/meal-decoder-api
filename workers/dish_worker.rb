# frozen_string_literal: true

require_relative '../require_app'
require_relative 'job_reporter'
require_app

require 'figaro'
require 'shoryuken'

module MealDecoder
  module Workers
    class DishProcessor
      def initialize(api_key = App.config.OPENAI_API_KEY)
        @mapper = Mappers::DishMapper.new(
          Gateways::OpenAIAPI.new(api_key)
        )
      end

      def process_request(request)
        dish_name = request['dish_name']
        message_id = request['message_id'] || request['request_id']
        channel_id = request['channel_id']

        puts "\n=== Processing dish request ==="
        puts "Dish: #{dish_name}"
        puts "Message ID: #{message_id}"
        puts "Channel: #{channel_id}"

        # Find or create initial dish record
        existing = Repository::For.klass(Entity::Dish).find_by_message_id(message_id)

        if existing
          puts "Found existing dish #{existing.id}, updating status to processing"
          Repository::For.klass(Entity::Dish).update_status(message_id, 'processing')
        else
          puts 'Creating initial dish record'
          initial_dish = Entity::Dish.new(
            id: nil,
            name: dish_name,
            ingredients: [],
            message_id:,
            status: 'processing'
          )
          existing = Repository::For.entity(initial_dish).create(initial_dish)
          puts "Created initial dish with ID: #{existing.id}"
        end

        # Process the dish through OpenAI
        puts 'Fetching dish information from OpenAI'
        processed_dish = @mapper.find(dish_name)
        puts "OpenAI returned #{processed_dish.ingredients.count} ingredients"

        # Create complete dish entity with all data
        complete_dish = Entity::Dish.new(
          id: existing.id,
          name: dish_name, # Use original dish name to maintain consistency
          ingredients: processed_dish.ingredients,
          message_id:,
          status: 'completed'
        )

        # Store in database with all ingredients
        stored_dish = Repository::For.entity(complete_dish).create(complete_dish)
        puts "Stored completed dish #{stored_dish.id} with #{stored_dish.ingredients.count} ingredients"

        # Verify storage
        final_dish = Repository::For.klass(Entity::Dish).find_id(stored_dish.id)
        puts "Final dish status: #{final_dish.status}"
        puts "Final ingredients count: #{final_dish.ingredients.count}"

        stored_dish
      rescue StandardError => e
        puts "PROCESSOR ERROR: #{e.message}"
        puts e.backtrace
        Repository::For.klass(Entity::Dish).update_status(message_id, 'failed') if message_id
        raise
      end
    end

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
      shoryuken_options queue: config.CLONE_QUEUE, auto_delete: true

      def initialize
        super
        @processor = DishProcessor.new
      end

      def perform(_sqs_msg, request)
        puts "\n=== WORKER RECEIVED REQUEST ==="
        puts "Request: #{request}"

        request_data = parse_request(request)
        job = JobReporter.new(request, self.class.config)

        begin
          validate_request!(request_data)
          job.report_progress(0, 'Started processing dish request')

          # Initial setup phase
          job.report_progress(10, 'Initializing dish processing...')
          
          # OpenAI processing phase
          job.report_progress(30, 'Fetching dish information from OpenAI...')
          dish = @processor.process_request(request_data)
          
          # Database update phase
          job.report_progress(70, 'Saving dish information to database...')

          # Verification phase
          raise 'Failed to process dish: No ingredients found' unless dish && dish.ingredients.any?

          # Completion
          Repository::For.klass(Entity::Dish).update_status(dish.message_id, 'completed')
          job.report_progress(100, 
            "Successfully processed dish: #{dish.name} with #{dish.ingredients.count} ingredients")

        rescue StandardError => e
          puts "WORKER ERROR: #{e.message}"
          puts e.backtrace
          job.report_error(e.message)

          update_status_on_failure(request_data)
          raise
        end
      end

      private

      def parse_request(request)
        case request
        when String
          begin
            JSON.parse(request)
          rescue JSON::ParserError
            JSON.parse(request.gsub('=>', ':'))
          end
        else
          request
        end
      end

      def validate_request!(request_data)
        dish_name = request_data['dish_name']
        raise 'Invalid request data' unless request_data
        raise 'Invalid dish name' if dish_name.nil? || dish_name.empty?
      end

      def update_status_on_failure(request_data)
        return unless request_data

        message_id = request_data['message_id'] || request_data['request_id']
        if message_id
          Repository::For.klass(Entity::Dish).update_status(message_id, 'failed')
        end
      end
    end
  end
end
