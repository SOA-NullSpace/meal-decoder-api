# frozen_string_literal: true

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
  end
end
