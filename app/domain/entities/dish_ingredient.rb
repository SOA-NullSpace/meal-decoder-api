# frozen_string_literal: true

# app/domain/entities/dish_ingredient.rb
require 'dry-struct'
require_relative '../values/types'

# The MealDecoder module encapsulates all entities related to the MealDecoder application.
module MealDecoder
  module Entity
    # Represents a link between dishes and their ingredients
    # along with additional nutritional data.
    class DishIngredient < Dry::Struct
      attribute :dish_id, Types::Integer.optional
      attribute :ingredient_id, Types::Integer.optional
      attribute :ingredient_name, Types::String
      attribute :calories_per_100g, Types::Float.default(0.0)
    end
  end
end
