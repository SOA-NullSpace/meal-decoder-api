# frozen_string_literal: true

require 'dry/monads'

module MealDecoder
  module Services
    # Service to create new dish from API and store in repository
    class CreateDish
      include Dry::Monads[:result]

      def initialize(validator: Validation::DishContract.new,
                     queue: Messaging::Queue.new(App.config.CLONE_QUEUE_URL, App.config))
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
      rescue StandardError => e
        Failure("Queue Error: #{e.message}")
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
