# frozen_string_literal: true

require_relative '../../../domain/entities/dish'
require_relative '../../../domain/entities/ingredient'
require_relative '../../../domain/lib/nutrition_calculator'

module MealDecoder
  module Mappers
    # DishMapper is responsible for mapping data retrieved via the OpenAI API
    # into a structured Dish entity. It fetches ingredients data, parses it,
    # and assembles a Dish entity with these ingredients.
    class DishMapper
      # Helper class responsible for cleaning and standardizing ingredient text
      # Removes common markers, bullet points, and other non-ingredient text
      # while maintaining the core ingredient information
      class IngredientCleaner
        MARKER_PATTERN = /^[\d\s.*•-]*/

        def initialize
          @patterns = [MARKER_PATTERN]
        end

        def clean(ingredient)
          @patterns.reduce(ingredient) do |text, pattern|
            text.gsub(pattern, '')
          end.strip
        end
      end

      def initialize(openai_gateway)
        @openai_gateway = openai_gateway
        @ingredient_cleaner = IngredientCleaner.new
      end

      def find(dish_name)
        puts "\n=== Starting the dish lookup process for: #{dish_name} ==="
        prepare_and_log_dish(dish_name)
      rescue StandardError => search_error
        handle_error(search_error)
      end

      private

      def handle_error(search_error)
        puts "ERROR in DishMapper: #{search_error.class} - #{search_error.message}"
        puts "Backtrace:\n#{search_error.backtrace.join("\n")}"
        raise search_error
      end

      def prepare_and_log_dish(dish_name)
        dish = fetch_and_prepare_dish(dish_name)
        log_creation(dish)
        dish
      end

      def fetch_and_prepare_dish(dish_name)
        ingredients_text = fetch_ingredients_text(dish_name)
        ingredients = parse_ingredients(ingredients_text)
        create_dish_entity(dish_name, ingredients)
      end

      def fetch_ingredients_text(dish_name)
        puts "Retrieving ingredients from OpenAI for: #{dish_name}"
        @openai_gateway.fetch_ingredients(dish_name).tap do |ingredients_text|
          puts "Ingredients retrieved: #{ingredients_text}"
        end
      end

      def parse_ingredients(ingredients_text)
        puts 'Parsing ingredients list...'
        ingredients_text.split("\n")
          .map(&:strip)
          .reject(&:empty?)
          .map { |ingredient| @ingredient_cleaner.clean(ingredient) }
          .reject(&:empty?)
      end

      def create_dish_entity(dish_name, ingredients)
        puts 'Assembling the Dish entity...'
        MealDecoder::Entity::Dish.new(
          id: nil,
          name: dish_name,
          ingredients:
        ).tap do |dish|
          puts "Created dish: #{dish.inspect}"
        end
      end

      def log_creation(dish)
        puts "Dish created: #{dish.inspect}"
        dish
      end
    end
  end
end
