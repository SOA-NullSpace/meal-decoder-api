# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../../spec_helper'

# Application domain entity and value objects for the MealDecoder service
# Implements core business logic for dish creation and management
module MealDecoder
  describe 'Test CreateDish service' do
    include MiniTestSetup

    before do
      @session = { searched_dishes: [] }
      @config = OpenStruct.new(
        OPENAI_API_KEY: MealDecoder::App.config.OPENAI_API_KEY,
        GOOGLE_CLOUD_API_TOKEN: MealDecoder::App.config.GOOGLE_CLOUD_API_TOKEN,
        AWS_ACCESS_KEY_ID: MealDecoder::App.config.AWS_ACCESS_KEY_ID,
        AWS_SECRET_ACCESS_KEY: MealDecoder::App.config.AWS_SECRET_ACCESS_KEY,
        AWS_REGION: MealDecoder::App.config.AWS_REGION,
        CLONE_QUEUE_URL: MealDecoder::App.config.CLONE_QUEUE_URL
      )
      VcrHelper.configure_vcr_for_apis(@config)
    end

    it 'HAPPY: should queue dish creation request' do
      VCR.use_cassette('service_create_pizza') do
        result = Services::CreateDish.new.call(
          dish_name: 'Pizza',
          session: @session
        )

        _(result).must_be_kind_of Dry::Monads::Success
        _(result.value!).must_be_kind_of Response::ApiResult
        _(result.value!.status).must_equal :processing
        _(result.value!.data[:dish_name]).must_equal 'Pizza'
        _(result.value!.data[:message_id]).wont_be_nil
      end
    end

    it 'SAD: should return Failure for invalid input' do
      VCR.use_cassette('service_create_invalid_dish') do
        # Test with invalid input (e.g., empty dish name)
        result = Services::CreateDish.new.call(
          dish_name: '',
          session: @session
        )

        _(result).must_be_kind_of Dry::Monads::Failure
        _(result.failure).must_be_kind_of Hash
        _(result.failure).must_include :dish_name
      end
    end

    it 'SAD: should return Failure when queue is unavailable' do
      # Create a service with a mock queue that raises an error
      bad_queue = Minitest::Mock.new
      bad_queue.expect :send, nil do |_message|
        raise StandardError, 'Queue unavailable'
      end

      service = Services::CreateDish.new(
        validator: Request::Dish.new, # Changed from Validation to Request
        queue: bad_queue
      )

      result = service.call(
        dish_name: 'Pizza',
        session: @session
      )

      _(result).must_be_kind_of Dry::Monads::Failure
      _(result.failure).must_include 'Queue Error'
      bad_queue.verify
    end
  end
end
