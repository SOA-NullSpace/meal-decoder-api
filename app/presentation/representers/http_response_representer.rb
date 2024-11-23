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
    end
  end
end
