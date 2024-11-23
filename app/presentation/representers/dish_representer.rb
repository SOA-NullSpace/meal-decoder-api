# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module MealDecoder
  module Representer
    # Represents essential Dish information for API output
    class Dish < Roar::Decorator
      include Roar::JSON
      include Roar::Hypermedia
      include Roar::Decorator::HypermediaConsumer

      property :id
      property :name
      property :ingredients
      property :total_calories
      property :calorie_level

      link :self do
        "#{Api.config.API_HOST}/api/v1/dishes/#{name}"
      end

      private

      def name
        represented.name.downcase.gsub(' ', '_')
      end
    end
  end
end
