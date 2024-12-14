# workers/job_reporter.rb
# frozen_string_literal: true

require_relative 'progress_publisher'

module MealDecoder
  module Workers
    # Handles job progress reporting through Faye websockets
    class JobReporter
      attr_reader :dish_name, :channel_id, :message_id

      def initialize(request_json, config)
        request_data = if request_json.is_a?(String)
                         JSON.parse(request_json)
                       else
                         request_json
                       end
        @dish_name = request_data['dish_name']
        @channel_id = request_data['channel_id']
        @message_id = request_data['message_id']
        @publisher = ProgressPublisher.new(config, @channel_id)
      end

      def report_progress(percentage, message)
        puts "Reporting progress: #{percentage}% - #{message}"
        @publisher.publish({
          percentage:,
          message:,
          dish_name: @dish_name,
          timestamp: Time.now.iso8601
        }.to_json)
      end

      def report_with_interval(seconds, start_percent, end_percent)
        step = (end_percent - start_percent) / seconds.to_f
        seconds.times do |i|
          current_percent = start_percent + (step * i)
          message = yield
          report_progress(current_percent.round, message)
          sleep(1)
        end
      end

      def report_error(error_message)
        report_progress(-1, "Error: #{error_message}")
      end
    end
  end
end
