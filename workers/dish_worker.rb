# frozen_string_literal: true

require_relative '../require_app'
require_relative 'job_reporter'
require_app

require 'figaro'
require 'shoryuken'

module MealDecoder
  module Workers
    # Processes dish requests by fetching ingredients and updating database records
    class DishProcessor
      def initialize(api_key = App.config.OPENAI_API_KEY)
        @mapper = Mappers::DishMapper.new(
          Gateways::OpenAIAPI.new(api_key)
        )
      end

      def process_request(request)
        request_info = extract_request_info(request)
        process_dish_request(request_info)
      rescue StandardError => e
        handle_processing_error(e, request_info[:message_id])
      end

      private

      def extract_request_info(request)
        {
          dish_name: request['dish_name'],
          message_id: request['message_id'] || request['request_id'],
          channel_id: request['channel_id']
        }
      end

      def process_dish_request(info)
        log_request_info(info)
        existing_dish = find_or_create_initial_dish(info)
        processed_dish = fetch_dish_info(info[:dish_name])
        store_complete_dish(existing_dish, processed_dish, info)
      end

      def log_request_info(info)
        puts "\n=== Processing dish request ==="
        puts "Dish: #{info[:dish_name]}"
        puts "Message ID: #{info[:message_id]}"
        puts "Channel: #{info[:channel_id]}"
      end

      def find_or_create_initial_dish(info)
        repository = Repository::For.klass(Entity::Dish)
        existing = repository.find_by_message_id(info[:message_id])

        if existing
          update_existing_dish(existing, info[:message_id])
        else
          create_initial_dish(info)
        end
      end

      def update_existing_dish(existing, message_id)
        puts "Found existing dish #{existing.id}, updating status to processing"
        Repository::For.klass(Entity::Dish).update_status(message_id, 'processing')
        existing
      end

      def create_initial_dish(info)
        initial_dish = build_initial_dish(info)
        stored_dish = Repository::For.entity(initial_dish).create(initial_dish)
        puts "Created initial dish with ID: #{stored_dish.id}"
        stored_dish
      end

      def build_initial_dish(info)
        Entity::Dish.new(
          id: nil,
          name: info[:dish_name],
          ingredients: [],
          message_id: info[:message_id],
          status: 'processing'
        )
      end

      def fetch_dish_info(dish_name)
        puts 'Fetching dish information'
        processed_dish = @mapper.find(dish_name)
        puts "OpenAI returned #{processed_dish.ingredients.count} ingredients"
        processed_dish
      end

      def store_complete_dish(existing, processed, info)
        complete_dish = build_complete_dish(existing, processed, info)
        store_and_verify_dish(complete_dish)
      end

      def build_complete_dish(existing, processed, info)
        Entity::Dish.new(
          id: existing.id,
          name: info[:dish_name],
          ingredients: processed.ingredients,
          message_id: info[:message_id],
          status: 'completed'
        )
      end

      def store_and_verify_dish(complete_dish)
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
        update_status_on_error(message_id)
        raise
      end

      def update_status_on_error(message_id)
        return unless message_id

        Repository::For.klass(Entity::Dish).update_status(message_id, 'failed')
      end
    end

    # Handles background processing of dish requests using Shoryuken
    class DishWorker
      include Shoryuken::Worker

      class << self
        def setup_environment
          configure_figaro
          configure_shoryuken
        end

        def config
          Figaro.env
        end

        private

        def configure_figaro
          Figaro.application = Figaro::Application.new(
            environment: ENV['RACK_ENV'] || 'development',
            path: File.expand_path('config/secrets.yml')
          )
          Figaro.load
        end

        def configure_shoryuken
          Shoryuken.sqs_client = Aws::SQS::Client.new(
            access_key_id: config.AWS_ACCESS_KEY_ID,
            secret_access_key: config.AWS_SECRET_ACCESS_KEY,
            region: config.AWS_REGION
          )
        end
      end

      setup_environment
      shoryuken_options queue: config.CLONE_QUEUE, auto_delete: true

      def initialize
        super
        @processor = DishProcessor.new
      end

      def perform(_sqs_msg, request)
        process_dish_job(request)
      rescue StandardError => e
        handle_worker_error(e)
        raise
      end

      private

      def process_dish_job(request)
        request_data = parse_request(request)
        job = JobReporter.new(request, self.class.config)

        execute_job_phases(request_data, job)
      end

      def execute_job_phases(request_data, job)
        validate_request!(request_data)
        report_initial_progress(job)
        process_dish(request_data, job)
      end

      def report_initial_progress(job)
        job.report_progress(0, 'Started processing dish request')
        job.report_progress(10, 'Initializing dish processing...')
      end

      def process_dish(request_data, job)
        job.report_progress(30, 'Fetching dish information...')
        dish = @processor.process_request(request_data)

        job.report_progress(70, 'Saving dish information to database...')
        verify_and_complete_dish(dish, job)
      end

      def verify_and_complete_dish(dish, job)
        raise 'Failed to process dish: No ingredients found' unless dish&.ingredients&.any?

        Repository::For.klass(Entity::Dish).update_status(dish.message_id, 'completed')
        report_completion(dish, job)
      end

      def report_completion(dish, job)
        job.report_progress(
          100,
          "Successfully processed dish: #{dish.name} with #{dish.ingredients.count} ingredients"
        )
      end

      def handle_worker_error(error)
        puts "WORKER ERROR: #{error.message}"
        puts error.backtrace
      end

      def parse_request(request)
        return request unless request.is_a?(String)

        begin
          JSON.parse(request)
        rescue JSON::ParserError
          JSON.parse(request.gsub('=>', ':'))
        end
      end

      def validate_request!(request_data)
        raise 'Invalid request data' unless request_data

        dish_name = request_data['dish_name']
        raise 'Invalid dish name' if dish_name.nil? || dish_name.empty?
      end
    end
  end
end
