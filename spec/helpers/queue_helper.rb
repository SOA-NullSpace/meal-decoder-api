# frozen_string_literal: true

module MealDecoder
  module Test
    # Mock Queue for testing
    class Queue
      def initialize
        @messages = []
      end

      def send(message)
        @messages << message
        SecureRandom.uuid # Return a fake message ID
      end

      def messages
        @messages
      end

      def clear
        @messages = []
      end
    end
  end
end
