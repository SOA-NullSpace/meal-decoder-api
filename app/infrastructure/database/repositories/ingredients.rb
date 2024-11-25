# frozen_string_literal: true

require_relative '../orm/ingredient_orm'

module MealDecoder
  module Repository
    # Repository for Ingredients
    class Ingredients
      def self.find_id(id)
        rebuild_entity Database::IngredientOrm.first(id:)
      end

      def self.find_name(name)
        rebuild_entity Database::IngredientOrm.first(name:)
      end

      def self.create(entity)
        return nil unless entity

        db_record = Database::IngredientOrm.find_or_create(name: entity.name,
                                                           calories_per_100g: entity.calories_per_100g || 0.0)
        rebuild_entity(db_record)
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        MealDecoder::Entity::Ingredient.new(
          id: db_record.id,
          name: db_record.name,
          calories_per_100g: db_record.calories_per_100g
        )
      end

      def self.ingredients_of_dish(dish_name)
        dish = Database::DishOrm.first(name: dish_name)
        return [] unless dish

        dish.ingredients.map do |ingredient|
          rebuild_entity(ingredient)
        end
      end
    end
  end
end
