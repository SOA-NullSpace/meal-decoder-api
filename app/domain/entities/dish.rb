# frozen_string_literal: true

require 'dry-struct'
require_relative '../values/types'

# The MealDecoder module encapsulates all entities related to the MealDecoder application.
module MealDecoder
  module Entity
    # The Dish class represents a dish with a name and a list of ingredients.
    # It uses dry-struct to ensure the attributes conform to specified data types.
    class Dish < Dry::Struct
      include Types

      attribute :id, Types::Integer.optional
      attribute :name, Types::Strict::String
      attribute :ingredients, Types::Array.of(Types::Strict::String)
      attribute? :status, Types::String.default('processing')
      attribute? :message_id, Types::String.optional

      def total_calories
        ingredients.sum { |ingredient| MealDecoder::Lib::NutritionCalculator.get_calories(ingredient) }
      end

      def calorie_level
        case total_calories
        when 0..400 then 'Low'
        when 401..700 then 'Moderate'
        else 'High'
        end
      end

      def to_h
        {
          id: id,
          name: name,
          ingredients: ingredients,
          total_calories: total_calories,
          calorie_level: calorie_level
        }
      end

      # def get_calories(ingredient)
      #   case ingredient.downcase
      #   when /beef|steak|ground beef/ then 250
      #   when /chicken|poultry/ then 165
      #   when /pork|ham|bacon/ then 300
      #   when /fish|salmon|tuna/ then 200
      #   when /shrimp|crab|lobster/ then 100
      #   when /egg/ then 155
      #   when /cheese|cheddar|mozzarella/ then 300
      #   when /milk|cream|yogurt/ then 60
      #   when /butter|margarine/ then 717
      #   when /oil|olive oil|canola oil/ then 120
      #   when /bread|bagel|bun/ then 265
      #   when /noodle|pasta|spaghetti|macaroni/ then 200
      #   when /rice|quinoa|couscous/ then 130
      #   when /potato|sweet potato/ then 77
      #   when /carrot|onion|garlic|ginger|bell pepper/ then 30
      #   when /tomato|cucumber|lettuce|spinach|greens/ then 20
      #   when /broccoli|cauliflower|zucchini|asparagus/ then 25
      #   when /apple|orange|banana|grape|berry/ then 50
      #   when /avocado/ then 160
      #   when /soup|broth|stock/ then 50
      #   when /sauce|soy sauce|ketchup|mustard/ then 30
      #   when /spice|seasoning|salt|pepper|herb|basil|oregano/ then 0
      #   when /sugar|honey|syrup/ then 300
      #   when /chocolate|candy|dessert/ then 500
      #   when /ice cream|frozen yogurt/ then 200
      #   when /nut|almond|peanut|walnut/ then 580
      #   when /flour|bread crumbs/ then 360
      #   when /bean|lentil|chickpea/ then 120
      #   when /tofu|tempeh/ then 70
      #   else 50  # Default for unknown ingredients
      #   end
      # end
    end
  end
end
