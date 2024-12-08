# frozen_string_literal: true

require 'dry/monads'

module MealDecoder
  module Services
    # Creates and manages queues for the application
    class QueueFactory
      def self.create(config = App.config)
        Messaging::Queue.new(config.CLONE_QUEUE_URL, config)
      end
    end

    # Service to create new dish from API and store in repository
    class CreateDish
      include Dry::Monads[:result]

      # Creates a service using test doubles if in test environment
      def self.with_queue(queue)
        new(validator: Request::Dish.new, queue:)
      end

      def initialize(validator: Request::Dish.new, queue: QueueFactory.create)
        @validator = validator
        @queue = queue
      end

      def call(input)
        validate(input)
          .bind { |data| queue_dish_request(data) }
      end

      private

      def validate(input)
        validation = @validator.call(dish_name: input[:dish_name])
        if validation.success?
          Success(input)
        else
          Failure(validation.errors.to_h)
        end
      end

      def queue_dish_request(input)
        message_id = send_to_queue(input)
        create_processing_response(input, message_id)
      rescue StandardError => error
        Failure("Queue Error: #{error.message}")
      end

      def send_to_queue(input)
        @queue.send({
                      dish_name: input[:dish_name],
                      timestamp: Time.now
                    })
      end

      def create_processing_response(input, message_id)
        Success(
          Response::ApiResult.new(
            status: :processing,
            message: 'Dish request is being processed',
            data: {
              dish_name: input[:dish_name],
              message_id:
            }
          )
        )
      end
    end
  end
end
