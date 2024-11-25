# frozen_string_literal: true

# app/domain/lib/nutrition_calculator.rb
require_relative '../values/nutrition_stats'

module MealDecoder
  module Lib
    # Provides methods to calculate nutritional values from given ingredients or dishes.
    class NutritionCalculator
      # Map ingredient names to their calorie values
      CALORIE_VALUES = {
        'beef'      => 250,
        'chicken'   => 165,
        'pork'      => 300,
        'fish'      => 200,
        'seafood'   => 100,
        'egg'       => 155,
        'dairy'     => 300,
        'oil'       => 120,
        'bread'     => 265,
        'noodle'    => 200,
        'rice'      => 130,
        'vegetable' => 30,
        'fruit'     => 50,
        'sauce'     => 30,
        'spice'     => 0,
        'default'   => 50
      }.freeze

      def self.calculate_dish_calories(dish_ingredients)
        return nil if dish_ingredients.empty?

        total_calories = dish_ingredients.sum(&:calories_per_100g)
        ingredient_count = dish_ingredients.size

        Value::NutritionStats.new(
          total_calories: total_calories,
          ingredient_count: ingredient_count,
          avg_calories_per_ingredient: (total_calories / ingredient_count.to_f).round(2)
        )
      end

      # Calculate the calories for a single ingredient
      def self.get_calories(ingredient)
        ingredient = ingredient.downcase
        CALORIE_VALUES.each do |key, cal|
          return cal if ingredient.include?(key)
        end
        CALORIE_VALUES['default'] # Fallback for unknown ingredients
      end
    end
  end
end
