# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module MealDecoder
  module Representer
    # Represents essential Dish information for API output
    class Dish < Roar::Decorator
      include Roar::JSON

      property :id
      property :name
      property :ingredients
      property :total_calories
      property :calorie_level
    end
  end
end
