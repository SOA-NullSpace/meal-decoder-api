# workers/progress_publisher.rb
# frozen_string_literal: true

require 'http'

module MealDecoder
  module Workers
    # Handles publishing progress updates to Faye
    class ProgressPublisher
      def initialize(config, channel_id)
        @config = config
        @channel_id = channel_id
        @api_host = config.API_HOST || 'http://localhost:9292'
      end

      def publish(message)
        faye_url = "#{@api_host}/faye"

        puts "Publishing to Faye: #{faye_url}, channel: /progress/#{@channel_id}"

        response = HTTP.headers(content_type: 'application/json')
          .post(faye_url, json: {
                  channel: "/progress/#{@channel_id}",
                  data: message
                })

        unless response.status.success?
          puts "Failed to publish progress: #{response.status} - #{response.body}"
          raise "Failed to publish progress: #{response.status}"
        end

        puts 'Successfully published progress update'
      rescue StandardError => e
        puts "Error publishing progress: #{e.message}"
        puts e.backtrace
        raise
      end
    end
  end
end
