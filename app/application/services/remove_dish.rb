# frozen_string_literal: true

module MealDecoder
  module Services
    # Service to remove a dish and update session
    class RemoveDish
      include Dry::Monads[:result]

      def initialize
        @repository = Repository::For.klass(Entity::Dish)
      end

      def call(dish_id:, session: {})
        remove_dish(dish_id).bind do |deleted_dish|
          update_session(session, deleted_dish)
        end
      end

      private

      def remove_dish(dish_id)
        dish = @repository.find_id(dish_id)
        return Failure("Could not find dish with ID: #{dish_id}") unless dish

        if @repository.delete_by_id(dish_id)
          Success(dish)
        else
          Failure('Could not delete dish')
        end
      end

      def update_session(session, dish)
        session[:searched_dishes]&.delete(dish.name)
        Success(dish)
      end
    end
  end
end
