# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'simplecov'
SimpleCov.start

require 'minitest/autorun'
require 'minitest/rg'
require 'yaml'
require 'vcr'
require 'webmock'
require 'rack/test'
require 'sequel'

require_relative 'helpers/vcr_helper'
require_relative 'helpers/database_helper'
require_relative '../require_app'
require_app

# Test setup module providing VCR and database management for test cases
module MiniTestSetup
  def self.included(base)
    base.class_eval do
      attr_reader :vcr_helper
    end
  end

  def setup
    @vcr_helper = VcrHelper
    @vcr_helper.setup_vcr
    DatabaseHelper.wipe_database
  end

  def teardown
    @vcr_helper&.eject_vcr
  end
end

CONFIG = YAML.safe_load_file('config/secrets.yml')['test']
OPENAI_API_KEY = MealDecoder::App.config.OPENAI_API_KEY
GOOGLE_CLOUD_API_TOKEN = MealDecoder::App.config.GOOGLE_CLOUD_API_TOKEN

def app
  MealDecoder::App
end
