# frozen_string_literal: true

module MealDecoder
  module Services
    # Manages session history for dishes
    class SessionManager
      include Dry::Monads[:result]

      def self.update_history(session, dish_name)
        searched_dishes = session[:searched_dishes] ||= []
        searched_dishes.unshift(dish_name)
        searched_dishes.uniq!
        Success(dish_name)
      end

      class << self
        include Dry::Monads[:result]
      end
    end
  end
end
