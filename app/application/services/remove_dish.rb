# frozen_string_literal: true

module MealDecoder
  module Services
    # Service to remove a dish and update session
    class RemoveDish
      include Dry::Monads[:result]

      def initialize
        @repository = Repository::For.klass(Entity::Dish)
      end

      def call(dish_name:, session: {})
        remove_dish(dish_name).bind do |deleted_name|
          update_session(session, deleted_name)
        end
      end

      private

      def remove_dish(dish_name)
        dish = @repository.find_name(dish_name)
        return Failure("Could not find dish: #{dish_name}") unless dish

        if @repository.delete(dish_name)
          Success(dish_name)
        else
          Failure('Could not delete dish')
        end
      end

      def update_session(session, dish_name)
        session[:searched_dishes]&.delete(dish_name)
        Success(dish_name)
      end
    end
  end
end
