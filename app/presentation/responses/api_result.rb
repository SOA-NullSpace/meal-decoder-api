# frozen_string_literal: true

module MealDecoder
  module Response
    # Response object for API results
    class ApiResult
      attr_reader :status, :message, :data

      SUCCESS = Set.new(
        [
          :ok,
          :created
        ]
      ).freeze

      FAILURE = Set.new(
        [
          :forbidden,
          :not_found,
          :bad_request,
          :conflict,
          :cannot_process,
          :internal_error
        ]
      ).freeze

      HTTP_CODE = {
        ok: 200,
        created: 201,
        forbidden: 403,
        not_found: 404,
        bad_request: 400,
        conflict: 409,
        cannot_process: 422,
        internal_error: 500
      }.freeze

      def initialize(status:, message:, data: nil)
        @status = status
        @message = message
        @data = data
      end

      def success?
        SUCCESS.include?(@status)
      end

      def failure?
        FAILURE.include?(@status)
      end

      def http_status_code
        HTTP_CODE[@status]
      end
    end
  end
end
