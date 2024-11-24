# frozen_string_literal: true

require 'vcr'
require 'webmock'

# Helper module for managing VCR cassettes in tests
module VcrHelper
  CASSETTES_FOLDER = 'spec/fixtures/cassettes'
  OPENAI_CASSETTE = 'openai_api'
  VISION_CASSETTE = 'google_vision_api'

  # Provides configuration options and settings for VCR cassette management
  # Handles default options, request matching, and sensitive data filtering
  # for API testing with VCR cassettes
  module VcrConfig
    def self.default_cassette_options
      {
        match_requests_on: [:method, :uri, :body]
      }
    end

    def self.sensitive_data_filters(config)
      {
        'OPENAI_API_KEY' => config.OPENAI_API_KEY,
        'GOOGLE_CLOUD_API_TOKEN' => config.GOOGLE_CLOUD_API_TOKEN
      }
    end
  end

  def self.setup_vcr
    VCR.configure do |config|
      config.cassette_library_dir = CASSETTES_FOLDER
      config.hook_into :webmock
    end
  end

  def self.configure_vcr_for_apis(config)
    VCR.configure do |configuration|
      apply_vcr_config(configuration, config)
    end
  end

  def self.eject_vcr
    VCR.eject_cassette
  end

  private_class_method def self.apply_vcr_config(configuration, config)
    apply_sensitive_data_filters(configuration, config)
    apply_default_options(configuration)
  end

  private_class_method def self.apply_sensitive_data_filters(configuration, config)
    VcrConfig.sensitive_data_filters(config).each do |key, value|
      configuration.filter_sensitive_data("<#{key}>") { value }
    end
  end

  private_class_method def self.apply_default_options(configuration)
    configuration.default_cassette_options = VcrConfig::default_cassette_options
  end
end
