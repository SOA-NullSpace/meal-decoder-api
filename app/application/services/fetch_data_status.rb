# frozen_string_literal: true

module MealDecoder
  module Services
    # Service class for fetching and managing dish processing status
    class FetchDishStatus
      include Dry::Monads[:result]

      def call(message_id)
        fetch_dish_status(message_id)
      end

      private

      def fetch_dish_status(message_id)
        dish = find_dish(message_id)
        build_response(dish, message_id)
      end

      def find_dish(message_id)
        Repository::For.klass(Entity::Dish).find_by_message_id(message_id)
      end

      def build_response(dish, message_id)
        if dish
          Success(build_success_response(dish, message_id))
        else
          Failure("No dish found for message ID: #{message_id}")
        end
      end

      def build_success_response(dish, message_id)
        Response::ApiResult.new(
          status: dish.status.to_sym,
          message: status_message(dish),
          data: build_response_data(dish, message_id)
        )
      end

      def build_response_data(dish, message_id)
        dish.status == 'completed' ? dish : { message_id: }
      end

      def status_message(dish)
        case dish.status
        when 'completed' then 'Dish processing completed'
        when 'failed' then 'Dish processing failed'
        else 'Dish is still being processed'
        end
      end
    end
  end
end
