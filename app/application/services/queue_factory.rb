# frozen_string_literal: true

require 'aws-sdk-sqs'

module MealDecoder
  module Services
    # Creates and manages queues for the application
    class QueueFactory
      def self.create(config = App.config)
        Messaging::Queue.new(config.CLONE_QUEUE_URL, config)
      end
    end
  end
end
