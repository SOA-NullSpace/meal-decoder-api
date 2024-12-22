# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../../spec_helper'

# Application domain entity and value objects for the MealDecoder service
# Provides core business logic and data structures for recipe management
module MealDecoder
  describe 'Integration Tests of External APIs and Database' do
    include MiniTestSetup

    before do
      @config = OpenStruct.new(
        OPENAI_API_KEY:,
        GOOGLE_CLOUD_API_TOKEN:
      )
      VcrHelper.configure_vcr_for_apis(@config)
      DatabaseHelper.wipe_database
    end

    describe 'Retrieve and store dish information' do
      before do
        @dishes_repo = MealDecoder::Repository::For.klass(MealDecoder::Entity::Dish)
      end

      it 'HAPPY: should be able to save dish from OpenAI API to database' do
        VCR.use_cassette('dish_spaghetti_carbonara', match_requests_on: %i[method uri body]) do
          # Create a dish using the API
          dish_name = 'Spaghetti Carbonara'
          api_dish = Mappers::DishMapper
            .new(Gateways::OpenAIAPI.new(OPENAI_API_KEY))
            .find(dish_name)

          # Store it in the database using the repository
          stored_dish = Repository::For.entity(api_dish).create(api_dish)

          # Verify the stored dish matches the original
          _(stored_dish.id).wont_be_nil
          _(stored_dish.name).must_equal(dish_name)
          _(stored_dish.ingredients.count).must_equal(api_dish.ingredients.count)

          # Verify each ingredient was stored correctly
          api_dish.ingredients.each do |ingredient|
            _(stored_dish.ingredients).must_include ingredient
          end
        end
      end

      it 'HAPPY: should be able to update existing dish' do
        VCR.use_cassette('dish_classic_pizza', match_requests_on: %i[method uri body]) do
          # First create a dish
          dish_name = 'Classic Pizza'
          api = Gateways::OpenAIAPI.new(OPENAI_API_KEY)
          mapper = Mappers::DishMapper.new(api)

          first_stored = Repository::For.entity(
            mapper.find(dish_name)
          ).create(mapper.find(dish_name))

          # Update the same dish with different cassette
          VCR.use_cassette('dish_classic_pizza_update', match_requests_on: %i[method uri body]) do
            updated_stored = Repository::For.entity(
              mapper.find(dish_name)
            ).create(mapper.find(dish_name))

            # Verify the update
            _(updated_stored.id).must_equal(first_stored.id)
            _(updated_stored.name).must_equal(first_stored.name)

            # Instead of comparing counts, verify that core ingredients are present
            core_ingredients = %w[Pizza Tomato Mozzarella Cheese Dough].map(&:downcase)
            has_core_ingredients = updated_stored.ingredients.any? do |ingredient|
              core_ingredients.any? { |core| ingredient.downcase.include?(core) }
            end
            _(has_core_ingredients).must_equal true

            # Verify ingredients are different from original (update happened)
            _(updated_stored.ingredients).wont_equal first_stored.ingredients
          end
        end
      end

      it 'SAD: should gracefully handle invalid dish names' do
        # ARRANGE - Create new dish with invalid name
        invalid_dish = MealDecoder::Entity::Dish.new(
          id: nil,
          name: '!@#$%^',
          ingredients: []
        )

        # ACT/ASSERT
        _(proc do
          @dishes_repo.create(invalid_dish)
        end).must_raise(Sequel::ValidationFailed)
      end
    end
  end
end
