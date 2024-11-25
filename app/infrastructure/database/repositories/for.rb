# frozen_string_literal: true

require_relative 'dishes'
require_relative 'ingredients'
require_relative '../../../domain/entities/dish_ingredient'

module MealDecoder
  module Repository
    # Finds the right repository for an entity object or class
    module For
      ENTITY_REPOSITORY = {
        MealDecoder::Entity::Dish           => Dishes,
        MealDecoder::Entity::Ingredient     => Ingredients,
        MealDecoder::Entity::DishIngredient => Dishes
      }.freeze

      def self.klass(entity_klass)
        ENTITY_REPOSITORY[entity_klass]
      end

      def self.entity(entity_object)
        ENTITY_REPOSITORY[entity_object.class]
      end
    end
  end
end
