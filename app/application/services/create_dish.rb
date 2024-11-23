# frozen_string_literal: true

require 'dry/transaction'

module MealDecoder
  module Service
    # Service to create new dish from API
    class CreateDish
      include Dry::Transaction

      step :validate_dish_request
      step :fetch_from_api
      step :store_dish

      private

      def validate_dish_request(input)
        request = Request::Dish.new.call(input)
        if request.success?
          Success(input)
        else
          Failure(Response::ApiResult.new(
            status: :cannot_process,
            message: request.errors.full_messages.join('; ')
          ))
        end
      end

      def fetch_from_api(input)
        if (dish = APIFactory.create_mapper.find(input[:dish_name]))
          Success(dish)
        else
          Failure(Response::ApiResult.new(
            status: :cannot_process,
            message: 'Could not find dish from API'
          ))
        end
      rescue StandardError => error
        Failure(Response::ApiResult.new(
          status: :internal_error,
          message: error.message
        ))
      end

      def store_dish(dish)
        stored_dish = Repository::For.entity(dish).create(dish)
        Success(Response::ApiResult.new(
          status: :created,
          message: 'Dish created successfully',
          data: stored_dish
        ))
      rescue StandardError => error
        Failure(Response::ApiResult.new(
          status: :internal_error,
          message: error.message
        ))
      end
    end
  end
end
