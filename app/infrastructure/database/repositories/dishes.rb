# frozen_string_literal: true

module MealDecoder
  module Repository
    # Repository for managing dish entities in the database
    # Handles CRUD operations and relationships with ingredients
    class Dishes
      # Creates or updates a dish entity in the database
      def self.create(entity)
        return nil unless entity

        db_dish = nil
        MealDecoder::App.db.transaction do
          # Create dish and manage ingredients in a single transaction
          db_dish = create_or_update_dish(entity)
        end

        rebuild_entity(db_dish)
      end

      # Retrieves all dishes from the database
      def self.all
        Database::DishOrm.all.map { |db_dish| rebuild_entity(db_dish) }
      end

      # Finds a dish by its name (case-insensitive)
      def self.find_name(name)
        decoded_name = CGI.unescape(name)
        db_record = Database::DishOrm.first(
          Sequel.function(:lower, :name) => decoded_name.downcase
        )
        rebuild_entity(db_record)
      end

      # Removes a dish and its ingredient associations from the database
      def self.delete(name)
        remove_dish_by_name(name)
      rescue StandardError => error
        log_delete_error(error)
        false
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        Entity::Dish.new(
          id: db_record.id,
          name: db_record.name,
          ingredients: db_record.ingredients.map(&:name)
        )
      end

      class << self
        private

        def create_or_update_dish(entity)
          db_dish = Database::DishOrm.find_or_create(name: entity.name)
          update_ingredients(db_dish, entity.ingredients)
          db_dish
        end

        def update_ingredients(db_dish, ingredients)
          db_dish.remove_all_ingredients
          ingredients.each do |ingredient_name|
            ingredient = Database::IngredientOrm.find_or_create(name: ingredient_name)
            db_dish.add_ingredient(ingredient)
          end
        end

        def find_dish_by_name(name)
          Database::DishOrm.first(
            Sequel.function(:lower, :name) => name.downcase
          )
        end

        def remove_dish_by_name(name)
          db_dish = find_dish_by_name(name)
          return false unless db_dish

          perform_dish_deletion(db_dish)
        end

        def perform_dish_deletion(db_dish)
          MealDecoder::App.db.transaction do
            db_dish.remove_all_ingredients
            db_dish.delete
          end
          true
        end

        def log_delete_error(error)
          puts "Error deleting dish: #{error.message}"
        end
      end
    end
  end
end
