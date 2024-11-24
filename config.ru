# frozen_string_literal: true

require_relative 'require_app'
require_app

run MealDecoder::App.freeze.app
