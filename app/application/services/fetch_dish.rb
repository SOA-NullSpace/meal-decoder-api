# frozen_string_literal: true

require 'dry/monads'

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
      rescue StandardError => e
        Failure("Database error: #{e.message}")
      end
    end

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

    # Data container for dish creation process
    class DishData
      attr_reader :name, :dish, :session

      def initialize(input)
        @name = input[:dish_name]
        @dish = input[:dish]
        @session = input[:session]
        ensure_session_array
      end

      def update_dish(new_dish)
        @dish = new_dish
        self
      end

      def save_to_repository
        dish_repo = DishRepository.new
        update_dish(dish_repo.save_dish(name, dish))
      end

      def add_to_history
        return self unless dish

        @session[:searched_dishes].unshift(dish.name)
        @session[:searched_dishes].uniq!
        self
      end

      private

      def ensure_session_array
        @session[:searched_dishes] ||= []
      end
    end

    # Service to create new dish from API
    class CreateDish
      include Dry::Monads[:result]

      def call(input)
        if valid_input?(input)
          create_dish(input)
        else
          Failure('Missing or empty dish name')
        end
      end

      private

      def create_dish(input)
        dish = APIFactory.create_mapper.find(input[:dish_name])
        stored_dish = Repository::For.entity(dish).create(dish)

        if stored_dish
          update_session(input[:session], stored_dish.name)
          Success(stored_dish)
        else
          Failure('API Error: Could not create dish')
        end
      rescue MealDecoder::Gateways::OpenAIAPI::UnknownDishError => e
        Failure("API Error: #{e.message}")
      rescue StandardError => e
        Failure("API Error: #{e.message}")
      end

      def valid_input?(input)
        input[:dish_name] && !input[:dish_name].empty?
      end

      def update_session(session, dish_name)
        return unless session

        session[:searched_dishes] ||= []
        session[:searched_dishes].unshift(dish_name)
        session[:searched_dishes].uniq!
      end
    end

    # Handles dish repository operations
    class DishRepository
      def initialize
        @repository = Repository::For.klass(Entity::Dish)
      end

      def save_dish(dish_name, dish)
        delete_existing_dish(dish_name)
        @repository.create(dish)
      end

      private

      def delete_existing_dish(dish_name)
        return unless (existing = @repository.find_name(dish_name))

        @repository.delete(existing.id)
      end
    end

    # Manages search history in session
    class SearchHistory
      def initialize(session)
        @session = session
        ensure_history_exists
      end

      def add(dish_name)
        searched_dishes.insert(0, dish_name)
        searched_dishes.uniq!
      end

      def remove(dish_name)
        searched_dishes.delete(dish_name)
      end

      private

      def searched_dishes
        @session[:searched_dishes]
      end

      def ensure_history_exists
        @session[:searched_dishes] ||= []
      end
    end

    class ListDishes
      include Dry::Monads[:result]

      begin
        dishes = Repository::For.klass(Entity::Dish).all
        Dry::Monads::Success(dishes)
      rescue StandardError => e
        Dry::Monads::Failure("Could not list dishes: #{e.message}")
      end
    end

    class RemoveDish
      include Dry::Monads[:result]

      def call(dish_name:, session: {})
        dish = Repository::For.klass(Entity::Dish).find_name(dish_name)

        if dish.nil?
          Failure("Could not find dish: #{dish_name}")
        elsif Repository::For.klass(Entity::Dish).delete(dish_name)
          session[:searched_dishes]&.delete(dish_name)
          Success(dish_name)
        else
          Failure('Could not delete dish')
        end
      rescue StandardError => e
        Failure(e.message)
      end
    end

    # Service to process image uploads and detect text
    class DetectMenuText
      include Dry::Monads[:result]

      def call(image_file)
        return Failure('No image file provided') if image_file.nil?

        validate_image(image_file)
          .bind { |valid_file| detect_text(valid_file) }
      end

      private

      def validate_image(file)
        return Failure('Invalid file format') unless valid_image?(file)

        Success(file)
      end

      def detect_text(file)
        text = api.detect_text(file[:tempfile].path)
        Success(text)
      rescue StandardError => e
        Failure("Text detection error: #{e.message}")
      end

      def api
        @api ||= Gateways::GoogleVisionAPI.new(App.config.GOOGLE_CLOUD_API_TOKEN)
      end

      def valid_image?(file)
        return false unless file.is_a?(Hash)
        return false unless file[:tempfile] && file[:type]

        ['image/jpeg', 'image/png'].include?(file[:type])
      end
    end
  end
end
