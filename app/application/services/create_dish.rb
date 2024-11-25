# frozen_string_literal: true

require 'dry/monads'

module MealDecoder
  module Services
    # Service to create new dish from API and store in repository
    class CreateDish
      include Dry::Monads[:result]

      def initialize(validator: Validation::DishContract.new,
                     result_handler: ResultHandler.new)
        @validator = validator
        @result_handler = result_handler
      end

      def call(input)
        validate(input)
          .bind { |data| process_dish(data) }
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

      def process_dish(input)
        dish_result = create_and_store_dish(input[:dish_name])
        @result_handler.handle_dish_result(dish_result, input[:session])
      rescue StandardError => error
        Failure("API Error: #{error.message}")
      end

      def create_and_store_dish(dish_name)
        dish = APIFactory.create_mapper.find(dish_name)
        stored_dish = Repository::For.entity(dish).create(dish)
        Success(stored_dish)
      end
    end
  end
end
