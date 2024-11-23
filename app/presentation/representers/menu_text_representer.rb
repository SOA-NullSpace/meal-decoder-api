# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module MealDecoder
  module Representer
    # Represents Menu Text Detection results for API output
    class MenuText < Roar::Decorator
      include Roar::JSON
      include Roar::Hypermedia
      include Roar::Decorator::HypermediaConsumer

      property :detected_text

      collection :possible_dishes, decorator: Representer::Dish

      link :self do
        "#{Api.config.API_HOST}/api/v1/detect_text"
      end
    end
  end
end
