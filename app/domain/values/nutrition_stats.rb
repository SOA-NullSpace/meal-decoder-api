# frozen_string_literal: true

# app/domain/values/nutrition_stats.rb
require 'dry-struct'
require_relative 'types'

module MealDecoder
  module Value
    # Contains aggregated nutritional statistics for a dish,
    # including total calories and average calories per ingredient.
    class NutritionStats < Dry::Struct
      include Types

      attribute :total_calories, Types::Float
      attribute :ingredient_count, Types::Integer
      attribute :avg_calories_per_ingredient, Types::Float

      def healthy?
        avg_calories_per_ingredient < 150
      end

      def calorie_level
        case total_calories
        when 0..400 then 'Low'
        when 401..700 then 'Moderate'
        else 'High'
        end
      end
    end
  end
end
