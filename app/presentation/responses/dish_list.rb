# frozen_string_literal: true

module MealDecoder
  module Response
    # Response object for a list of dishes
    class DishList
      def initialize(dishes)
        @dishes = dishes
      end

      def data
        @dishes
      end

      def status
        return :not_found if @dishes.empty?

        :ok
      end

      def message
        return 'Could not find any dishes' if @dishes.empty?

        "Found #{@dishes.length} dishes"
      end
    end
  end
end
