# frozen_string_literal: true

require 'securerandom'

# app/domain/values/progress_tracker.rb
module MealDecoder
  module Value
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
