# frozen_string_literal: true

module MealDecoder
  module Services
    # Service class for fetching and managing dish processing status
    class FetchDishStatus
      include Dry::Monads[:result]

      def initialize(dish_repository: Repository::For.klass(Entity::Dish))
        @dish_repository = dish_repository
        @response_mapper = ResponseMapper.new
      end

      def call(message_id)
        fetch_dish_status(message_id)
      end

      private

      attr_reader :dish_repository, :response_mapper

      def fetch_dish_status(message_id)
        dish = dish_repository.find_by_message_id(message_id)
        build_response(dish)
      end

      def build_response(dish)
        return Failure("No dish found for message ID: #{dish.message_id}") unless dish

        Success(response_mapper.map(dish))
      end
    end

    # Builds API responses for dish status
    class ResponseMapper
      def initialize
        setup_message_maps
        setup_data_maps
      end

      def map(dish)
        Response::ApiResult.new(
          status: dish.status.to_sym,
          message: message_for(dish),
          data: data_for(dish)
        )
      end

      private

      attr_reader :status_message_map, :default_message, :status_data_map

      def setup_message_maps
        @status_message_map = {
          'completed' => 'Dish processing completed',
          'failed'    => 'Dish processing failed'
        }.freeze
        @default_message = 'Dish is still being processed'
      end

      def setup_data_maps
        message_id_response = ->(dish) { { message_id: dish.message_id } }
        @status_data_map = {
          'completed'  => ->(dish) { dish },
          'failed'     => message_id_response,
          'processing' => message_id_response
        }.freeze
      end

      def message_for(dish)
        status_message_map.fetch(dish.status, default_message)
      end

      def data_for(dish)
        status_data_map.fetch(dish.status, status_data_map['processing']).call(dish)
      end
    end
  end
end
