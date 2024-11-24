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
          Dry::Monads::Success(dish)
        else
          Dry::Monads::Failure("Could not find dish: #{dish_name}")
        end
      rescue StandardError => e
        Failure(e.message)
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
          begin
            dish = APIFactory.create_mapper.find(input[:dish_name])
            stored_dish = Repository::For.entity(dish).create(dish)

            if stored_dish
              # Add to session history if provided
              input[:session][:searched_dishes]&.unshift(stored_dish.name)
              input[:session][:searched_dishes]&.uniq!

              Dry::Monads::Success(stored_dish)
            else
              Dry::Monads::Failure("Could not create dish")
            end
          rescue StandardError => e
            Dry::Monads::Failure(e.message)
          end
        else
          Dry::Monads::Failure('Missing or empty dish name')
        end
      end

      private

      def valid_input?(input)
        input[:dish_name] && !input[:dish_name].empty?
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
        else
          if Repository::For.klass(Entity::Dish).delete(dish_name)
            session[:searched_dishes]&.delete(dish_name)
            Success(dish_name)
          else
            Failure('Could not delete dish')
          end
        end
      rescue StandardError => e
        Failure(e.message)
      end
    end

    # Service to process image uploads and detect text
    class DetectMenuText
      include Dry::Monads[:result]

      def call(image_file)
        return Dry::Monads::Failure("No image file provided") if image_file.nil?
        return Dry::Monads::Failure("Invalid image format") unless valid_image?(image_file)

        begin
          text = api.detect_text(image_file[:tempfile].path)
          Dry::Monads::Success(text)
        rescue StandardError => e
          Dry::Monads::Failure(e.message)
        end
      end

      private

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
