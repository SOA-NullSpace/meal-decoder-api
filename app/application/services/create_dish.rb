# frozen_string_literal: true

require 'dry/monads'
require 'securerandom'

# app/application/services/create_dish.rb
module MealDecoder
  module Services
    class CreateDish
      include Dry::Monads[:result]

      def self.with_queue(queue)
        new(validator: Request::Dish.new, queue:)
      end

      def initialize(validator: Request::Dish.new, queue: QueueFactory.create)
        @validator = validator
        @queue = queue
      end

      def call(input)
        validate(input)
          .bind { |data| create_progress_tracker(data) }
          .bind { |data| generate_tracking_info(data) }
          .bind { |data| queue_dish_request(data) }
      end

      private

      def create_progress_tracker(input)
        tracker = Value::ProgressTracker.new("Processing dish: #{input[:dish_name]}")
        Success(input.merge(tracker:))
      end

      def validate(input)
        validation = @validator.call(dish_name: input[:dish_name])
        if validation.success?
          Success(input)
        else
          Failure(validation.errors.to_h)
        end
      end

      def generate_tracking_info(input)
        channel_id = SecureRandom.uuid
        Success(input.merge(channel_id:))
      end

      def queue_dish_request(input)
        message_id = send_to_queue(input)
        create_processing_response(input, message_id)
      rescue StandardError => error
        puts "Queue Error: #{error.message}"
        puts error.backtrace
        Failure("Queue Error: #{error.message}")
      end

      def send_to_queue(input)
        message_id = SecureRandom.uuid
        message = {
          dish_name: input[:dish_name],
          channel_id: input[:tracker].channel_id,
          message_id: message_id,
          timestamp: Time.now.to_i
        }
        puts "Sending message to queue: #{message.inspect}"
        @queue.send(message)
        message_id
      end

      def create_processing_response(input, message_id)
        Success(
          Response::ApiResult.new(
            status: :processing,
            message: 'Dish request is being processed',
            data: {
              dish_name: input[:dish_name],
              message_id:,
              channel_id: input[:tracker].channel_id
            }
          )
        )
      end
    end
  end
end
