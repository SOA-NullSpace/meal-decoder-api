# frozen_string_literal: true

module MealDecoder
  module Workers
    # Handles progress tracking calculations and reporting
    class ProgressCalculator
      def initialize(seconds, start_percent, end_percent)
        @seconds = seconds
        @start_percent = start_percent
        @end_percent = end_percent
        @step = calculate_step
      end

      def current_percent(iteration)
        (@start_percent + (@step * iteration)).round
      end

      private

      def calculate_step
        (@end_percent - @start_percent) / @seconds.to_f
      end
    end
  end
end
