# frozen_string_literal: true

module MealDecoder
  module Services
    # Represents a dish operation result
    class DishResult
      def initialize(result, session_manager = SessionManager)
        @result = result
        @session_manager = session_manager
      end

      def success?
        @result.success?
      end

      def value
        return nil unless success?

        @result.value!
      end

      def value!
        @result.value!
      end

      def error
        @result.failure
      end

      def update_session(session)
        return self unless success?

        @session_manager.update_history(session, value!.name)
        self
      end

      def to_monad
        @result
      end
    end
  end
end
