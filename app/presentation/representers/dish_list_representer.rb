# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'
require_relative 'dish_representer'

module MealDecoder
  module Representer
    # Represents list of dishes for API output
    class DishList < Roar::Decorator
      include Roar::JSON

      collection :dishes, extend: MealDecoder::Representer::Dish

      def initialize(dishes)
        super(OpenStruct.new(dishes: dishes))
      end
    end
  end
end
