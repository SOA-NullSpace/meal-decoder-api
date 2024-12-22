# frozen_string_literal: true

require 'http'

module MealDecoder
  module Workers
    # Handles progress reporting through websocket messages
    class ProgressPublisher
      def initialize(config, channel_id)
        @config = config
        @channel_id = channel_id
        @api_host = config.API_HOST || 'http://localhost:9292'
      end

      def publish(message)
        send_progress_update(message)
      end

      private

      def send_progress_update(message)
        response = send_faye_request(message)
        handle_response(response)
      rescue StandardError => error
        handle_publishing_error(error)
      end

      def send_faye_request(message)
        faye_url = "#{@api_host}/faye"
        json_message = message.to_json

        HTTP.headers('Content-Type' => 'application/json')
          .post(faye_url, json: {
                  channel: "/progress/#{@channel_id}",
                  data: json_message
                })
      end

      def build_message_payload(message)
        {
          channel: "/progress/#{@channel_id}",
          data: message
        }
      end

      def handle_response(response)
        if response.status.success?
          puts 'Successfully published progress update'
        else
          handle_failed_response(response)
        end
      end

      def handle_failed_response(response)
        error_message = "Failed to publish progress: #{response.status} - #{response.body}"
        puts error_message
        raise error_message
      end

      def handle_publishing_error(error)
        puts "Error publishing progress: #{error.message}"
        puts error.backtrace
        raise
      end
    end
  end
end
