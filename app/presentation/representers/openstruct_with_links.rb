# frozen_string_literal: true

module MealDecoder
  module Representer
    # Extends OpenStruct to support hypermedia links in representers
    class OpenStructWithLinks < OpenStruct
      def initialize(hash = nil)
        super
        @links = []
      end

      def links
        @links
      end

      protected

      def links=(new_links)
        @links = new_links
      end
    end
  end
end
