# frozen_string_literal: true

module MealDecoder
  module Representer
    # OpenStruct for deserializing json with hypermedia
    class OpenStructWithLinks < OpenStruct
      attr_accessor :links
    end
  end
end
