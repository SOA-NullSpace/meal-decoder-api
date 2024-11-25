# frozen_string_literal: true

module MealDecoder
  module Services
    # Result handler for dish operations
    class ResultHandler
      def initialize(session_manager = SessionManager)
        @session_manager = session_manager
      end

      def handle_dish_result(monad_result, session)
        DishResult.new(monad_result, @session_manager)
          .update_session(session)
          .to_monad
      end
    end
  end
end
