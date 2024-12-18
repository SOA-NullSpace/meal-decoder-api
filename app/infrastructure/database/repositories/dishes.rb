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
          puts "Creating/updating dish: #{entity.name}"
          db_dish = create_or_update_dish(entity)

          # Only update ingredients if they are provided
          update_ingredients(db_dish, entity.ingredients) if entity.ingredients&.any?

          puts "Dish created/updated: #{db_dish.inspect}"
        end

        result = rebuild_entity(db_dish)
        puts "Rebuilt entity: #{result.inspect}"
        result
      end

      def self.find_id(id)
        db_record = Database::DishOrm.where(id:).eager(:ingredients).first
        rebuild_entity(db_record)
      end

      def self.delete_by_id(id)
        remove_dish_by_id(id)
      rescue StandardError => error
        log_delete_error(error)
        false
      end

      def self.all
        all_dishes = Database::DishOrm
          .order(Sequel.desc(:created_at))
          .eager(:ingredients)
          .all

        puts "\nFetching all dishes from database..."
        
        # Map all dishes to entities, including those in processing
        dishes = all_dishes.map do |db_dish|
          dish = rebuild_entity(db_dish)
          puts "Found dish: ID=#{dish.id}, Name=#{dish.name}, Status=#{dish.status}, Ingredients=#{dish.ingredients&.count}"
          dish
        end

        # Only filter out dishes with no data at all
        result = dishes.compact
        puts "Returning #{result.length} dishes"
        result
      end

      def self.find_name(name)
        decoded_name = CGI.unescape(name)
        db_record = Database::DishOrm
          .where(Sequel.function(:lower, :name) => decoded_name.downcase)
          .eager(:ingredients)
          .first
        rebuild_entity(db_record)
      end

      def self.delete(name)
        remove_dish_by_name(name)
      rescue StandardError => error
        log_delete_error(error)
        false
      end

      def self.find_by_message_id(message_id)
        puts "Looking for dish with message_id: #{message_id}"
        db_record = Database::DishOrm.where(message_id:).eager(:ingredients).first
        puts "Found dish: #{db_record&.inspect}"
        rebuild_entity(db_record)
      end

      def self.update_status(message_id, new_status)
        puts "Updating status for message_id #{message_id} to #{new_status}"
        db_record = Database::DishOrm.where(message_id:).eager(:ingredients).first
        return nil unless db_record

        db_record.update(status: new_status)
        result = rebuild_entity(db_record)
        puts "Updated dish: #{result.inspect}"
        result
      rescue StandardError => e
        puts "Error updating status: #{e.message}"
        puts e.backtrace
        raise
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        Entity::Dish.new(
          id: db_record.id,
          name: db_record.name,
          ingredients: db_record.ingredients.map(&:name),
          status: db_record.status,
          message_id: db_record.message_id
        )
      end

      class << self
        private

        def create_or_update_dish(entity)
          Database::DishOrm.find_or_create(name: entity.name) do |d|
            d.status = entity.status || 'processing'
            d.message_id = entity.message_id
          end
        end

        def update_ingredients(db_dish, ingredients)
          # Remove existing ingredients
          db_dish.remove_all_ingredients

          # Add new ingredients
          ingredients.each do |ingredient_name|
            ingredient = Database::IngredientOrm.find_or_create(name: ingredient_name)
            db_dish.add_ingredient(ingredient)
          end
        end

        def find_dish_by_name(name)
          Database::DishOrm
            .where(Sequel.function(:lower, :name) => name.downcase)
            .eager(:ingredients)
            .first
        end

        def remove_dish_by_name(name)
          db_dish = find_dish_by_name(name)
          return false unless db_dish

          perform_dish_deletion(db_dish)
        end

        def remove_dish_by_id(id)
          db_dish = Database::DishOrm.where(id:).eager(:ingredients).first
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
