# frozen_string_literal: true

require 'dry/validation'

module MealDecoder
  module Request
    # Request validation for image uploads
    class Image < Dry::Validation::Contract
      # Use params to define the shape of request parameters
      params do
        required(:image_file).filled(:hash) do
          required(:tempfile).filled
          required(:type).filled(:string)
          required(:filename).filled(:string)
        end
      end

      rule(:image_file) do
        if value
          key.failure('must provide an image file') unless value.key?(:tempfile)

          # Verify file type
          key.failure('must be a JPG, JPEG, or PNG image') unless ['image/jpeg', 'image/png'].include?(value[:type])

          # Verify file size (e.g., max 5MB)
          key.failure('must be smaller than 5MB') if value[:tempfile].size > 5 * 1024 * 1024 # 5MB

          # Verify filename extension
          key.failure('must have a valid image extension') unless value[:filename].match?(/\.(jpg|jpeg|png)$/i)
        end
      end
    end
  end
end
