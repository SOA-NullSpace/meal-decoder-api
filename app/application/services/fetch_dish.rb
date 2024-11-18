# frozen_string_literal: true

require 'dry/monads'
require 'dry/transaction'

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
      rescue StandardError => fetch_error
        Failure("Error fetching dish: #{fetch_error.message}")
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
      include Dry::Transaction

      step :validate_input
      step :fetch_from_api
      step :save_to_repository
      step :add_to_history

      private

      def validate_input(input)
        puts "Validating input with dish_name: #{input[:dish_name]}"
        data = DishData.new(input)
        return Failure('Dish name is required') if data.name.to_s.empty?

        Success(data)
      end

      def fetch_from_api(data)
        puts "Fetching from API for dish: #{data.name}"
        dish = APIFactory.create_mapper.find(data.name)
        Success(data.update_dish(dish))
      rescue StandardError => api_error
        Failure("API Error: #{api_error.message}")
      end

      def save_to_repository(data)
        puts "Saving to repository: #{data.dish.name}"
        Success(data.save_to_repository)
      rescue StandardError => db_error
        Failure("Database Error: #{db_error.message}")
      end

      def add_to_history(data)
        puts "Adding to history, session before: #{data.session[:searched_dishes]}"
        data.add_to_history
        puts "Session after update: #{data.session[:searched_dishes]}"
        Success(data.dish)
      rescue StandardError => session_error
        Failure("Session Error: #{session_error.message}")
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

    # Service to process image uploads and detect text
    class DetectMenuText
      include Dry::Monads[:result]

      def call(image_file)
        api = Gateways::GoogleVisionAPI.new(App.config.GOOGLE_CLOUD_API_TOKEN)
        text_result = api.detect_text(image_file[:tempfile].path)
        Success(text_result)
      rescue StandardError => vision_error
        Failure("Text detection error: #{vision_error.message}")
      end
    end

    # Service to remove dish from history
    class RemoveDish
      include Dry::Transaction

      step :validate_input
      step :remove_from_history
      step :delete_from_database

      private

      def validate_input(input)
        data = DishData.new(input)
        return Failure('Dish name is required') if data.name.to_s.empty?

        Success(data)
      end

      def remove_from_history(data)
        SearchHistory.new(data.session).remove(data.name)
        Success(data)
      rescue StandardError => history_error
        Failure("Session Error: #{history_error.message}")
      end

      def delete_from_database(data)
        DishRepository.new.save_dish(data.name, nil)
        Success('Dish removed successfully')
      rescue StandardError => delete_error
        Failure("Database Error: #{delete_error.message}")
      end
    end
  end
end
