# workers/progress_publisher.rb
# frozen_string_literal: true

require 'http'

# In your web API project (api-meal-decoder)
# ./workers/progress_publisher.rb

module MealDecoder
  module Workers
    class ProgressPublisher 
      def initialize(config, channel_id)
        @config = config
        @channel_id = channel_id
        @api_host = config.API_HOST || 'http://localhost:9292' # Make sure this points to your API
      end

      def publish(message)
        faye_url = "#{@api_host}/faye"
        
        puts "Publishing to Faye: #{faye_url}, channel: /progress/#{@channel_id}"
        
        begin
          response = HTTP.headers('Content-Type' => 'application/json')
            .post(faye_url, json: {
              channel: "/progress/#{@channel_id}",
              data: message
            })
          
          if response.status.success?
            puts 'Successfully published progress update'
          else  
            puts "Failed to publish progress: #{response.status} - #{response.body}"
            raise "Failed to publish progress: #{response.status}"
          end
        rescue => e
          puts "Error publishing progress: #{e.message}"
          puts e.backtrace
          raise # Re-raise to ensure the worker sees the error
        end
      end
    end
  end
end
