# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module MealDecoder
  module Representer
    # Represents essential Ingredient information for API output
    class Ingredient < Roar::Decorator
      include Roar::JSON

      property :name
      property :calories_per_100g
    end
  end
end
