# frozen_string_literal: true

module MealDecoder
  module Response
    # Encapsulates API response information
    class ApiResponse
      attr_reader :status, :message, :data

      def initialize(status:, message:, data: nil)
        @status = status
        @message = message
        @data = data
      end

      def successful?
        [200, 201].include?(Representer::HttpResponse::STATUS_CODES[status])
      end
    end
  end
end
