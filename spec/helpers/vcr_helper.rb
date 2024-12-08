# frozen_string_literal: true

require 'vcr'
require 'webmock'

# Helper module for managing VCR cassettes in tests
module VcrHelper
  CASSETTES_FOLDER = 'spec/fixtures/cassettes'
  OPENAI_CASSETTE = 'openai_api'
  VISION_CASSETTE = 'google_vision_api'

  # Handles VCR configuration settings and setup
  # Provides methods for configuring cassette library and endpoints
  module Config
    module_function

    def cassette_library_config(config)
      config.cassette_library_dir = CASSETTES_FOLDER
      config.hook_into :webmock
    end

    def ignore_endpoints(config)
      config.ignore_localhost = true # for acceptance tests
      config.ignore_hosts 'sqs.us-east-1.amazonaws.com'
      config.ignore_hosts 'sqs.ap-northeast-1.amazonaws.com'
    end
  end

  module_function

  def setup_vcr
    VCR.configure do |config|
      Config.cassette_library_config(config)
      Config.ignore_endpoints(config)
    end
  end

  def configure_vcr_for_apis(config)
    VCR.configure do |configuration|
      apply_vcr_config(configuration, config)
    end
  end

  def eject_vcr
    VCR.eject_cassette
  end

  def apply_vcr_config(configuration, config)
    apply_sensitive_data_filters(configuration, config)
    apply_default_options(configuration)
  end

  def apply_sensitive_data_filters(configuration, config)
    VcrConfig.sensitive_data_filters(config).each do |key, value|
      configuration.filter_sensitive_data("<#{key}>") { value }
    end
  end

  def apply_default_options(configuration)
    configuration.default_cassette_options = VcrConfig.default_cassette_options
  end

  # Manages VCR configuration options and sensitive data filtering
  # Provides default settings and data masking for API credentials
  module VcrConfig
    module_function

    def default_cassette_options
      {
        match_requests_on: %i[method uri body]
      }
    end

    def sensitive_data_filters(config)
      {
        'OPENAI_API_KEY'         => config.OPENAI_API_KEY,
        'GOOGLE_CLOUD_API_TOKEN' => config.GOOGLE_CLOUD_API_TOKEN
      }
    end
  end
end
