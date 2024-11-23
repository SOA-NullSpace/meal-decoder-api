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
      property :data, render_nil: true

      def http_status_code
        {
          ok: 200,
          created: 201,
          forbidden: 403,
          not_found: 404,
          bad_request: 400,
          conflict: 409,
          cannot_process: 422,
          internal_error: 500
        }[represented.status]
      end
    end
  end
end
