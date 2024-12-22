# frozen_string_literal: true

module MealDecoder
  module Repository
    # Handles ingredient processing and association with dishes
    class DishIngredientProcessor
      class << self
        def process(db_dish, ingredients)
          return unless ingredients&.any?

          associate_ingredients(db_dish, create_ingredients(ingredients))
        end

        private

        def create_ingredients(ingredients)
          ingredients.map do |name|
            Database::IngredientOrm.find_or_create(name:)
          end
        end

        def associate_ingredients(db_dish, ingredient_records)
          db_dish.remove_all_ingredients if db_dish.ingredients.any?
          ingredient_records.each { |ingredient| db_dish.add_ingredient(ingredient) }
        end
      end
    end

    # Repository class responsible for managing dish entities in the database.
    # Handles CRUD operations, ingredient associations, and status updates for dishes.
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
          find_and_rebuild_entity(id:)
        end

        def all
          fetch_all_dishes.map { |dish| rebuild_entity(dish) }.compact
        end

        def find_name(name)
          decoded_name = CGI.unescape(name)
          find_and_rebuild_entity(
            Sequel.function(:lower, :name) => decoded_name.downcase
          )
        end

        def find_by_message_id(message_id)
          find_and_rebuild_entity(message_id:)
        end

        def update_status(message_id, new_status)
          update_dish_status(message_id, new_status)
        rescue StandardError => error
          log_error('Error updating status', error)
          raise
        end

        private

        def update_dish_status(message_id, new_status)
          db_record = find_record(message_id:)
          return nil unless db_record

          db_record.update(status: new_status)
          rebuild_entity(db_record)
        end

        def find_and_rebuild_entity(conditions)
          rebuild_entity(find_record(conditions))
        end

        def find_record(conditions)
          Database::DishOrm.where(conditions).eager(:ingredients).first
        end

        def create_dish_transaction(entity)
          db_dish = create_or_update_dish(entity)
          DishIngredientProcessor.process(db_dish, entity.ingredients)
          db_dish
        end

        def create_or_update_dish(entity)
          Database::DishOrm.find_or_create(
            name: entity.name,
            status: entity.status || 'processing',
            message_id: entity.message_id
          )
        end

        def rebuild_entity(db_record)
          return nil unless db_record

          Entity::Dish.new(
            id: db_record.id,
            name: db_record.name,
            ingredients: db_record.ingredients.map(&:name),
            status: db_record.status,
            message_id: db_record.message_id
          )
        end

        def fetch_all_dishes
          Database::DishOrm
            .order(Sequel.desc(:created_at))
            .eager(:ingredients)
            .all
        end

        def log_error(message, error)
          puts "#{message}: #{error.message}"
          puts error.backtrace
        end
      end
    end
  end
end
