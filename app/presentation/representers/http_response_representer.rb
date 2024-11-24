# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module MealDecoder
  module Representer
    # Represents HTTP response for API output
    class HttpResponse < Roar::Decorator
      include Roar::JSON

      property :status
      property :message
      property :data

      STATUS_CODES = {
        ok: 200,
        created: 201,
        not_found: 404,
        bad_request: 400,
        internal_error: 500
      }.freeze

      def http_status_code
        STATUS_CODES[represented.status] || 500
      end
    end
  end
end
