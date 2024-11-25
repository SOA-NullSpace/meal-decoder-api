# frozen_string_literal: true

require 'dry/monads'
require 'dry/validation'

module MealDecoder
  module Services
    # Factory for creating API-related objects
    class APIFactory
      def self.create_gateway
        api_key = App.config.OPENAI_API_KEY
        Gateways::OpenAIAPI.new(api_key)
      end

      def self.create_mapper
        new_gateway = create_gateway
        Mappers::DishMapper.new(new_gateway)
      end
    end

    # Manages session history for dishes
    class SessionManager
      include Dry::Monads[:result]

      def self.update_history(session, dish_name)
        searched_dishes = session[:searched_dishes] ||= []
        searched_dishes.unshift(dish_name)
        searched_dishes.uniq!
        Success(dish_name)
      end

      class << self
        include Dry::Monads[:result]
      end
    end

    # Represents a dish operation result
    class DishResult
      def initialize(result, session_manager = SessionManager)
        @result = result
        @session_manager = session_manager
      end

      def success?
        @result.success?
      end

      def value
        return nil unless success?

        @result.value!
      end

      def value!
        @result.value!
      end

      def error
        @result.failure
      end

      def update_session(session)
        return self unless success?

        @session_manager.update_history(session, value!.name)
        self
      end

      def to_monad
        @result
      end
    end

    # Result handler for dish operations
    class ResultHandler
      def initialize(session_manager = SessionManager)
        @session_manager = session_manager
      end

      def handle_dish_result(monad_result, session)
        DishResult.new(monad_result, @session_manager)
          .update_session(session)
          .to_monad
      end
    end

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

    # Service to create new dish from API and store in repository
    class CreateDish
      include Dry::Monads[:result]

      def initialize(validator: Validation::DishContract.new,
                     result_handler: ResultHandler.new)
        @validator = validator
        @result_handler = result_handler
      end

      def call(input)
        validate(input)
          .bind { |data| process_dish(data) }
      end

      private

      def validate(input)
        validation = @validator.call(dish_name: input[:dish_name])
        if validation.success?
          Success(input)
        else
          Failure(validation.errors.to_h)
        end
      end

      def process_dish(input)
        dish_result = create_and_store_dish(input[:dish_name])
        @result_handler.handle_dish_result(dish_result, input[:session])
      rescue StandardError => error
        Failure("API Error: #{error.message}")
      end

      def create_and_store_dish(dish_name)
        dish = APIFactory.create_mapper.find(dish_name)
        stored_dish = Repository::For.entity(dish).create(dish)
        Success(stored_dish)
      end
    end

    # Service to remove a dish and update session
    class RemoveDish
      include Dry::Monads[:result]

      def initialize
        @repository = Repository::For.klass(Entity::Dish)
      end

      def call(dish_name:, session: {})
        remove_dish(dish_name).bind do |deleted_name|
          update_session(session, deleted_name)
        end
      end

      private

      def remove_dish(dish_name)
        dish = @repository.find_name(dish_name)
        return Failure("Could not find dish: #{dish_name}") unless dish

        if @repository.delete(dish_name)
          Success(dish_name)
        else
          Failure('Could not delete dish')
        end
      end

      def update_session(session, dish_name)
        session[:searched_dishes]&.delete(dish_name)
        Success(dish_name)
      end
    end

    # Service to process image uploads and detect text
    class DetectMenuText
      include Dry::Monads[:result]

      def initialize(validator = Validation::ImageContract.new)
        @validator = validator
      end

      def call(image_file)
        validate_file(image_file)
          .bind { |file| process_image(file) }
      end

      private

      def validate_file(file)
        maybe_validate_file(file)
          .bind { |valid_file| validate_content(valid_file) }
      end

      def maybe_validate_file(file)
        return Failure('No image file provided') unless file

        Success(file)
      end

      def validate_content(file)
        validation_result = @validator.call(file: file)
        if validation_result.success?
          Success(file)
        else
          Failure(validation_result.errors.to_h)
        end
      end

      def process_image(file)
        text = api.detect_text(file[:tempfile].path)
        Success(text)
      rescue StandardError => error
        Failure("Text detection error: #{error.message}")
      end

      def api
        @api ||= Gateways::GoogleVisionAPI.new(App.config.GOOGLE_CLOUD_API_TOKEN)
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
