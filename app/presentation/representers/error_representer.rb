# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module MealDecoder
  module Representer
    # Represents error messages for API output
    class Error < Roar::Decorator
      include Roar::JSON

      property :status
      property :message
    end
  end
end
