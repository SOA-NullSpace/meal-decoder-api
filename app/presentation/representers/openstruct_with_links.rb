# frozen_string_literal: true

module MealDecoder
  module Representer
    # Extends OpenStruct to support hypermedia links in representers
    class OpenStructWithLinks < OpenStruct
      def initialize(hash = nil)
        super
        @links = []
      end

      attr_reader :links

      protected

      attr_writer :links
    end
  end
end
