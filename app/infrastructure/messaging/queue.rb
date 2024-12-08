# frozen_string_literal: true

require 'aws-sdk-sqs'

module MealDecoder
  module Messaging
    ## Queue wrapper for AWS SQS
    # Requires: AWS credentials loaded in ENV or through config file
    class Queue
      IDLE_TIMEOUT = 5 # seconds

      def initialize(queue_url, config)
        @queue_url = queue_url
        @sqs = Aws::SQS::Client.new(
          access_key_id: config.AWS_ACCESS_KEY_ID,
          secret_access_key: config.AWS_SECRET_ACCESS_KEY,
          region: config.AWS_REGION
        )
      end

      ## Sends message to queue
      # Returns: message ID
      def send(message)
        msg = @sqs.send_message(
          queue_url: @queue_url,
          message_body: message.to_json
        )
        msg.message_id
      end

      ## Receives message from queue
      # Returns: message object
      def receive
        result = @sqs.receive_message(
          queue_url: @queue_url,
          max_number_of_messages: 1
        )
        result.messages.first
      end

      def delete(receipt)
        @sqs.delete_message(
          queue_url: @queue_url,
          receipt_handle: receipt
        )
      end

      def exist?
        @sqs.get_queue_attributes(
          queue_url: @queue_url,
          attribute_names: ['All']
        )
        true
      rescue StandardError
        false
      end
    end
  end
end
