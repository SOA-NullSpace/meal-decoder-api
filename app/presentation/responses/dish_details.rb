# frozen_string_literal: true

module MealDecoder
  module Response
    # Response object for a single dish's details
    class DishDetails
      def initialize(dish)
        @dish = dish
      end

      def data
        @dish
      end

      def status
        return :not_found unless @dish

        :ok
      end

      def message
        return 'Could not find dish' unless @dish

        'Found dish details'
      end
    end
  end
end
