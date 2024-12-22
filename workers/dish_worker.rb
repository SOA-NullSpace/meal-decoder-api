# frozen_string_literal: true

require_relative '../require_app'
require_relative 'job_reporter'
require_app

require 'figaro'
require 'shoryuken'

module MealDecoder
  module Workers
    # Handles request parsing and validation
    class RequestParser
      def self.parse(request)
        case request
        when String then parse_json_string(request)
        else request
        end
      end

      def self.extract_info(request)
        {
          dish_name: request['dish_name'],
          message_id: request['message_id'] || request['request_id'],
          channel_id: request['channel_id']
        }
      end

      private_class_method def self.parse_json_string(request)
        JSON.parse(request)
      rescue JSON::ParserError
        JSON.parse(request.gsub('=>', ':'))
      end
    end

    # Manages dish entity creation and updates
    class DishBuilder
      def self.build_initial(info)
        Entity::Dish.new(
          id: nil,
          name: info[:dish_name],
          ingredients: [],
          message_id: info[:message_id],
          status: 'processing'
        )
      end

      def self.build_complete(existing, processed, info)
        Entity::Dish.new(
          id: existing.id,
          name: info[:dish_name],
          ingredients: processed.ingredients,
          message_id: info[:message_id],
          status: 'completed'
        )
      end
    end

    # Formats messages for various worker operations
    class MessageFormatter
      def self.completion_message(dish)
        "Successfully processed dish: #{dish.name} with #{dish.ingredients.count} ingredients"
      end
    end

    # Manages progress reporting for dish processing jobs
    class ProgressReporter
      def initialize(job_reporter)
        @job_reporter = job_reporter
      end

      def report_initial_progress
        @job_reporter.report_progress(0, 'Started processing dish request')
        @job_reporter.report_progress(10, 'Initializing dish processing...')
      end

      def report_completion(completed_dish)
        @job_reporter.report_progress(
          100,
          MessageFormatter.completion_message(completed_dish)
        )
      end
    end

    # Handles dish status update operations
    class StatusManager
      def self.update_on_error(message_id)
        return unless message_id

        Repository::For.klass(Entity::Dish).update_status(message_id, 'failed')
      end

      def self.update_to_processing(existing_dish, message_id)
        puts "Found existing dish #{existing_dish.id}, updating status to processing"
        Repository::For.klass(Entity::Dish).update_status(message_id, 'processing')
        existing_dish
      end

      def self.update_to_completed(message_id)
        Repository::For.klass(Entity::Dish).update_status(message_id, 'completed')
      end
    end

    # Custom error class for request validation failures
    class ValidationError < StandardError; end

    # Handles request validation logic and error handling
    class RequestValidator
      def self.validate!(request_data)
        raise ValidationError, 'Invalid request data' unless request_data

        dish_name = request_data['dish_name']
        return if dish_name && !dish_name.empty?

        raise ValidationError, 'Invalid dish name'
      end
    end

    # Processes dish creation requests and manages dish lifecycle
    class DishProcessor
      def initialize(api_key = App.config.OPENAI_API_KEY)
        @mapper = Mappers::DishMapper.new(
          Gateways::OpenAIAPI.new(api_key)
        )
      end

      def process_request(request)
        request_info = RequestParser.extract_info(request)
        process_dish_request(request_info)
      rescue StandardError => error
        handle_processing_error(error, request_info[:message_id])
      end

      private

      def process_dish_request(info)
        existing_dish = find_or_create_initial_dish(info)
        processed_dish = fetch_dish_info(info[:dish_name])
        store_complete_dish(existing_dish, processed_dish, info)
      end

      def find_or_create_initial_dish(info)
        repository = Repository::For.klass(Entity::Dish)
        message_id = info[:message_id]
        existing = repository.find_by_message_id(message_id)
        existing ? StatusManager.update_to_processing(existing, message_id) : create_initial_dish(info)
      end

      def create_initial_dish(info)
        initial_dish = DishBuilder.build_initial(info)
        stored_dish = Repository::For.entity(initial_dish).create(initial_dish)
        puts "Created initial dish with ID: #{stored_dish.id}"
        stored_dish
      end

      def fetch_dish_info(dish_name)
        puts 'Fetching dish information'
        processed_dish = @mapper.find(dish_name)
        puts "OpenAI returned #{processed_dish.ingredients.count} ingredients"
        processed_dish
      end

      def store_complete_dish(existing, processed, info)
        complete_dish = DishBuilder.build_complete(existing, processed, info)
        stored_dish = Repository::For.entity(complete_dish).create(complete_dish)
        verify_storage(stored_dish)
        stored_dish
      end

      def verify_storage(stored_dish)
        final_dish = Repository::For.klass(Entity::Dish).find_id(stored_dish.id)
        puts "Final dish status: #{final_dish.status}"
        puts "Final ingredients count: #{final_dish.ingredients.count}"
      end

      def handle_processing_error(error, message_id)
        puts "PROCESSOR ERROR: #{error.message}"
        puts error.backtrace
        StatusManager.update_on_error(message_id)
        raise
      end
    end

    # Background worker for processing dish requests asynchronously
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
        @validator = RequestValidator
      end

      def perform(_sqs_msg, request)
        process_dish_job(request)
      rescue StandardError => error
        handle_worker_error(error)
        raise
      end

      private

      def process_dish_job(request)
        request_data = RequestParser.parse(request)
        reporter = ProgressReporter.new(JobReporter.new)

        execute_job_phases(request_data, reporter)
      end

      def execute_job_phases(request_data, reporter)
        @validator.validate!(request_data)
        reporter.report_initial_progress
        process_dish(request_data, reporter)
      end

      def process_dish(request_data, reporter)
        dish = @processor.process_request(request_data)
        verify_and_complete_dish(dish, reporter)
      end

      def verify_and_complete_dish(dish, reporter)
        raise 'Failed to process dish: No ingredients found' unless dish&.ingredients&.any?

        StatusManager.update_to_completed(dish.message_id)
        reporter.report_completion(dish)
      end

      def handle_worker_error(error)
        puts "WORKER ERROR: #{error.message}"
        puts error.backtrace
      end
    end
  end
end
