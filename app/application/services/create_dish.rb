# frozen_string_literal: true

require 'dry/monads'
require 'securerandom'

module MealDecoder
  module Services
    # Service for creating new dish entries and managing the creation process
    # Handles validation, progress tracking, and request queueing
    class CreateDish
      include Dry::Monads[:result]

      def self.with_queue(queue)
        new(validator: Request::Dish.new, queue:)
      end

      def initialize(validator: Request::Dish.new, queue: QueueFactory.create)
        @validator = validator
        @queue = queue
        @tracker = Value::ProgressTracker
      end

      def call(input)
        validate(input)
          .bind { |data| add_progress_tracking(data) }
          .bind { |data| queue_request(data) }
      end

      private

      def validate(input)
        validation = @validator.call(dish_name: input[:dish_name])
        validation.success? ? Success(input) : Failure(validation.errors.to_h)
      end

      def add_progress_tracking(data)
        tracker = @tracker.new("Processing dish: #{data[:dish_name]}")
        channel_id = SecureRandom.uuid
        Success(data.merge(tracker:, channel_id:))
      end

      def queue_request(data)
        message_id = send_to_queue(data)
        build_processing_response(data, message_id)
      rescue StandardError => error
        log_and_return_error(error)
      end

      def send_to_queue(data)
        message_id = SecureRandom.uuid
        queue_message = QueueMessage.new(data, message_id)
        @queue.send(queue_message.to_h)
        message_id
      end

      def build_processing_response(data, message_id)
        Success(
          Response::ApiResult.new(
            status: :processing,
            message: 'Dish request is being processed',
            data: ResponseData.new(data, message_id).to_h
          )
        )
      end

      def log_and_return_error(error)
        error_message = "Queue Error: #{error.message}"
        puts error_message
        puts error.backtrace
        Failure(error_message)
      end
    end

    # Represents a message to be sent to the processing queue
    # Contains dish information and tracking metadata
    class QueueMessage
      def initialize(data, message_id)
        @data = data
        @message_id = message_id
      end

      def to_h
        {
          dish_name: @data[:dish_name],
          channel_id: @data[:tracker].channel_id,
          message_id: @message_id,
          timestamp: Time.now.to_i
        }
      end
    end

    # Represents the response data structure for API responses
    # Contains dish information and tracking identifiers
    class ResponseData
      def initialize(data, message_id)
        @data = data
        @message_id = message_id
      end

      def to_h
        {
          dish_name: @data[:dish_name],
          message_id: @message_id,
          channel_id: @data[:tracker].channel_id
        }
      end
    end
  end
end
