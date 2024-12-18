# frozen_string_literal: true

require 'dry/validation'

module MealDecoder
  module Request
    # Request validation for dish operations
    class Dish < Dry::Validation::Contract
      # Use params to define the shape of request parameters
      params do
        required(:dish_name).filled(:string)
      end

      rule(:dish_name) do
        # Check if dish name contains only letters and spaces from any language
        key.failure('must contain only letters and spaces') unless /\A[\p{L}\p{N}\s]+\z/u.match?(value)

        # Check length
        key.failure('must be less than 100 characters') if value.length > 100

        # Check if empty after stripping
        key.failure('must not be empty') if value.strip.empty?
      end
    end
  end
end
