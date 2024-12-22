# frozen_string_literal: true

require_relative 'progress_calculator'

module MealDecoder
  module Workers
    # Handles job progress reporting through Faye websockets
    class JobReporter
      def report_with_interval(seconds, start_percent, end_percent, &)
        calculator = ProgressCalculator.new(seconds, start_percent, end_percent)
        report_progress_steps(seconds, calculator, &)
      end

      private

      def report_progress_steps(seconds, calculator)
        seconds.times do |iteration|
          message = yield
          report_progress(calculator.current_percent(iteration), message)
          sleep(1)
        end
      end
    end
  end
end
