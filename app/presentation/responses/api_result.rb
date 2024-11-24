# frozen_string_literal: true

module MealDecoder
  module Response
    # Response object for API results
    class ApiResult
      attr_reader :status, :message, :data

      def initialize(status:, message:, data: nil)
        @status = status
        @message = message
        @data = data
      end
    end
  end
end
