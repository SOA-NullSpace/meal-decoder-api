# frozen_string_literal: true

module MealDecoder
  module Response
    # Response object for menu text detection
    class MenuText
      def initialize(text_result)
        @text_result = text_result
      end

      def data
        @text_result
      end

      def status
        return :not_found if @text_result.empty?

        :ok
      end

      def message
        return 'No text detected in image' if @text_result.empty?

        'Successfully detected menu text'
      end
    end
  end
end
