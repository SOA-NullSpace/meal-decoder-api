# frozen_string_literal: true

module MealDecoder
  module Services
    class FetchDishStatus
      include Dry::Monads[:result]

      def call(message_id)
        dish = Repository::For.klass(Entity::Dish).find_by_message_id(message_id)
        if dish
          Success(
            Response::ApiResult.new(
              status: dish.status.to_sym,
              message: status_message(dish),
              data: dish.status == 'completed' ? dish : { message_id: }
            )
          )
        else
          Failure("No dish found for message ID: #{message_id}")
        end
      end

      private

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
