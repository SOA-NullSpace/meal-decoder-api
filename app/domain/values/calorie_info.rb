# frozen_string_literal: true

# app/domain/values/calorie_info.rb
require 'dry-struct'
require_relative 'types'

module MealDecoder
  module Value
    # Encapsulates calorie information per 100g and provides a method
    # to calculate total calories based on portion size.
    class CalorieInfo < Dry::Struct
      attribute :calories_per_100g, Types::Float.default(0.0)
      attribute :portion_size, Types::Float.default(100.0)

      def total_calories
        (calories_per_100g * portion_size / 100.0).round(2)
      end
    end
  end
end
