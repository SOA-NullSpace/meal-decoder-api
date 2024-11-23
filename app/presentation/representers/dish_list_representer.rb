# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'
require_relative 'dish_representer'

module MealDecoder
  module Representer
    # Represents list of dishes for API output
    class DishList < Roar::Decorator
      include Roar::JSON
      include Roar::Hypermedia
      include Roar::Decorator::HypermediaConsumer

      # collection :dishes, extend: Representer::Dish, class: OpenStruct
      collection :dishes, extend: MealDecoder::Representer::Dish, class: OpenStruct

      link :self do
        "#{Api.config.API_HOST}/api/v1/dishes"
      end
    end
  end
end
