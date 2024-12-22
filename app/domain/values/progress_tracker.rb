# frozen_string_literal: true

require 'securerandom'

module MealDecoder
  module Value
    # Value object for tracking progress of asynchronous operations
    # Provides a channel-based mechanism for real-time status updates
    class ProgressTracker
      attr_reader :channel_id, :status, :task

      def initialize(task)
        @channel_id = SecureRandom.uuid
        @status = :pending
        @task = task
      end

      def to_h
        {
          channel_id: @channel_id,
          status: @status,
          task: @task
        }
      end
    end
  end
end
