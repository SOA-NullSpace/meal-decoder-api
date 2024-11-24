# frozen_string_literal: true

module MealDecoder
  module Repository
    class Dishes
      def self.create(entity)
        return nil unless entity

        db_dish = nil
        MealDecoder::App.db.transaction do
          # Create or find the dish
          db_dish = Database::DishOrm.find_or_create(name: entity.name)

          # Remove existing ingredients if any
          db_dish.remove_all_ingredients

          # Add new ingredients
          entity.ingredients.each do |ingredient_name|
            ingredient = Database::IngredientOrm.find_or_create(name: ingredient_name)
            db_dish.add_ingredient(ingredient)
          end
        end

        rebuild_entity(db_dish)
      end

      def self.all
        Database::DishOrm.all.map { |db_dish| rebuild_entity(db_dish) }
      end

      def self.find_name(name)
        # Remove URL encoding
        decoded_name = CGI.unescape(name)
        db_record = Database::DishOrm.first(Sequel.function(:lower, :name) => decoded_name.downcase)
        rebuild_entity(db_record)
      end

      def self.delete(name)
        db_dish = Database::DishOrm.first(Sequel.function(:lower, :name) => name.downcase)
        return false unless db_dish

        MealDecoder::App.db.transaction do
          db_dish.remove_all_ingredients
          db_dish.delete
        end
        true
      rescue StandardError => e
        puts "Error deleting dish: #{e.message}"
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
    end
  end
end
