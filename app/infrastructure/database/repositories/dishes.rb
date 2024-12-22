# frozen_string_literal: true

module MealDecoder
  module Repository
    # Repository for managing dish entities in the database
    # Handles CRUD operations and relationships with ingredients
    class Dishes
      class << self
        def create(entity)
          return nil unless entity

          db_dish = nil
          MealDecoder::App.db.transaction do
            db_dish = create_dish_transaction(entity)
          end

          rebuild_entity(db_dish)
        end

        def find_id(id)
          db_record = Database::DishOrm.where(id:).eager(:ingredients).first
          rebuild_entity(db_record)
        end

        def all
          fetch_all_dishes.map do |db_dish|
            process_dish(db_dish)
          end.compact
        end

        def find_name(name)
          decoded_name = CGI.unescape(name)
          db_record = Database::DishOrm
            .where(Sequel.function(:lower, :name) => decoded_name.downcase)
            .eager(:ingredients)
            .first
          rebuild_entity(db_record)
        end

        def find_by_message_id(message_id)
          puts "Looking for dish with message_id: #{message_id}"
          db_record = Database::DishOrm.where(message_id:).eager(:ingredients).first
          puts "Found dish: #{db_record&.inspect}"
          rebuild_entity(db_record)
        end

        def update_status(message_id, new_status)
          process_status_update(message_id, new_status)
        rescue StandardError => e
          handle_status_update_error(e)
        end

        private

        def create_dish_transaction(entity)
          db_dish = create_or_update_dish(entity)
          update_ingredients(db_dish, entity.ingredients) if entity.ingredients&.any?
          puts "Dish created/updated: #{db_dish.inspect}"
          db_dish
        end

        def fetch_all_dishes
          puts "\nFetching all dishes from database..."
          Database::DishOrm
            .order(Sequel.desc(:created_at))
            .eager(:ingredients)
            .all
        end

        def process_dish(db_dish)
          dish = rebuild_entity(db_dish)
          log_dish_info(dish)
          dish
        end

        def log_dish_info(dish)
          info = "ID=#{dish.id}, Name=#{dish.name}, Status=#{dish.status}"
          puts "Found dish: #{info}, Ingredients=#{dish.ingredients&.count}"
        end

        def process_status_update(message_id, new_status)
          db_record = find_dish_by_message_id(message_id)
          return nil unless db_record

          update_dish_status(db_record, new_status)
        end

        def find_dish_by_message_id(message_id)
          Database::DishOrm.where(message_id:).eager(:ingredients).first
        end

        def update_dish_status(db_record, new_status)
          db_record.update(status: new_status)
          result = rebuild_entity(db_record)
          puts "Updated dish: #{result.inspect}"
          result
        end

        def handle_status_update_error(error)
          puts "Error updating status: #{error.message}"
          puts error.backtrace
          raise
        end
      end
    end
  end
end
