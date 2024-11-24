# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module MealDecoder
  module Representer
    # Represents Menu Text Detection results for API output
    class MenuText < Roar::Decorator
      include Roar::JSON

      property :status
      property :message
      property :data
    end
  end
end
