# frozen_string_literal: true

module MealDecoder
  module Test
    # Test implementation of Queue for specs
    class TestQueue
      attr_reader :messages

      def initialize
        @messages = []
      end

      def send(message)
        @messages << message
        'fake_message_id'
      end

      def clear
        @messages = []
      end
    end

    # Helper module to manage queue setup in tests
    module QueueHelper
      def self.setup
        MealDecoder::Services::QueueFactory.class_eval do
          def self.create(_config = nil)
            TestQueue.new
          end
        end
      end
    end
  end
end
