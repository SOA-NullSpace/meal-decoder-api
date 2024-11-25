# frozen_string_literal: true

require 'dry/validation'

module MealDecoder
  module Services
    # Service to fetch dish details
    class FetchDish
      include Dry::Monads[:result]

      def call(dish_name)
        dish = Repository::For.klass(Entity::Dish).find_name(dish_name)
        if dish
          Success(dish)
        else
          Failure('Could not find that dish')
        end
      rescue StandardError => error
        Failure("Database error: #{error.message}")
      end
    end

    # Validation contracts for input data
    module Validation
      # Constants for validation rules
      VALID_IMAGE_TYPES = ['image/jpeg', 'image/png'].freeze

      # Contract for image validation
      class ImageValidator
        def initialize(allowed_types = VALID_IMAGE_TYPES)
          @allowed_types = allowed_types
        end

        def valid_type?(type)
          @allowed_types.include?(type)
        end
      end

      # Validates dish input data
      class DishContract < Dry::Validation::Contract
        params do
          required(:dish_name).filled(:string)
        end

        rule(:dish_name) do
          key.failure('must not be empty') if value.strip.empty?
        end
      end

      # Validates image file data
      class ImageContract < Dry::Validation::Contract
        option :validator, default: proc { ImageValidator.new }

        params do
          required(:file).hash do
            required(:tempfile)
            required(:type).filled(:string)
          end
        end

        rule(:file) do
          next unless value[:type]

          key.failure('invalid image type') unless validator.valid_type?(value[:type])
        end
      end
    end
  end
end
