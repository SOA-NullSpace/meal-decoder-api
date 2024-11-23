# frozen_string_literal: true

require_relative '../orm/dish_orm'
require_relative '../../../domain/lib/nutrition_calculator'

module MealDecoder
  module Repository
    # Repository for Dishes
    class Dishes
      # Manages the deletion of dishes and their associated records from the database
      # Handles the transaction management and error handling for deletion operations
      class DeletionManager
        def self.delete_dish(id)
          return nil unless id

          db = Sequel::Model.db
          perform_deletion(db, id)
        rescue Sequel::Error => e
          handle_deletion_error(e)
        end

        def self.perform_deletion(db, id)
          db.transaction do
            db[:dishes_ingredients].where(dish_id: id).delete
            db[:dishes].where(id:).delete
          end
        end

        def self.handle_deletion_error(database_error)
          puts "Database deletion error: #{database_error.message}"
          nil
        end
      end

      def self.find_id(id)
        rebuild_entity Database::DishOrm.first(id:)
      end

      # def self.find_name(name)
      #   rebuild_entity Database::DishOrm.first(name:)
      # end
      def self.find_name(name)
        normalized_name = normalize_name(name)
        puts "Looking up dish with normalized name: #{normalized_name}"
        rebuild_entity Database::DishOrm.first(Sequel.function(:lower, :name) => normalized_name.downcase)
      end

      # def self.create(entity)
      #   return nil unless entity

      #   db_dish = Database::DishOrm.find_or_create(name: entity.name)
      #   handle_ingredients(db_dish, entity.ingredients)
      #   rebuild_entity(db_dish)
      # end
      def self.create(entity)
        return nil unless entity

        normalized_name = normalize_name(entity.name)
        puts "Creating dish with normalized name: #{normalized_name}"
        db_dish = Database::DishOrm.find_or_create(name: normalized_name)
        handle_ingredients(db_dish, entity.ingredients)
        rebuild_entity(db_dish)
      end

      def self.handle_ingredients(db_dish, ingredient_names)
        ingredient_names.each do |ingredient_name|
          ingredient = Database::IngredientOrm.find_or_create(name: ingredient_name)
          db_dish.add_ingredient(ingredient) unless db_dish.ingredients.include?(ingredient)
        end
      end

      def self.delete(id)
        DeletionManager.delete_dish(id)
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        ingredients = db_record.ingredients
        total_calories = calculate_calories(ingredients)

        Entity::Dish.new(
          id: db_record.id,
          name: db_record.name,
          ingredients: ingredients.map(&:name),
          total_calories:
        )
      end

      def self.calculate_calories(ingredients)
        ingredients.sum { |ingredient| Lib::NutritionCalculator.get_calories(ingredient.name) }
      end

      def self.normalize_name(name)
        # Normalize to Title Case and handle whitespace
        name.to_s.strip.split(/\s+/).map(&:capitalize).join(' ')
      end
    end
  end
end
