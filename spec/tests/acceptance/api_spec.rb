# frozen_string_literal: true

require_relative '../../spec_helper'

def app
  MealDecoder::App
end

# Define a test queue class
module MealDecoder
  module Test
    # Test implementation of message queue for specs
    class TestQueue
      def send(message)
        puts "Test queue received message: #{message}"
        'fake_message_id'
      end
    end
  end
end

describe 'API acceptance tests' do
  include Rack::Test::Methods
  include MiniTestSetup

  before do
    DatabaseHelper.wipe_database

    @config = OpenStruct.new(
      OPENAI_API_KEY: MealDecoder::App.config.OPENAI_API_KEY,
      GOOGLE_CLOUD_API_TOKEN: MealDecoder::App.config.GOOGLE_CLOUD_API_TOKEN,
      AWS_ACCESS_KEY_ID: MealDecoder::App.config.AWS_ACCESS_KEY_ID,
      AWS_SECRET_ACCESS_KEY: MealDecoder::App.config.AWS_SECRET_ACCESS_KEY,
      AWS_REGION: MealDecoder::App.config.AWS_REGION,
      CLONE_QUEUE: MealDecoder::App.config.CLONE_QUEUE
    )
    VcrHelper.configure_vcr_for_apis(@config)

    # Replace the QueueFactory create method
    MealDecoder::Services::QueueFactory.class_eval do
      def self.create(_config = nil)
        MealDecoder::Test::TestQueue.new
      end
    end
  end

  describe 'Dish API tests' do
    it 'HAPPY: should accept dish creation request' do
      # Create first dish
      header 'CONTENT_TYPE', 'application/json'
      dish_data = { dish_name: 'Spaghetti Carbonara' }.to_json

      VCR.use_cassette('dish_carbonara') do
        post '/api/v1/dishes', dish_data
        _(last_response.status).must_equal 202

        response = JSON.parse(last_response.body)
        _(response['status']).must_equal 'processing'
        _(response['data']['dish_name']).must_equal 'Spaghetti Carbonara'
        _(response['data']['message_id']).wont_be_nil
        _(response['progress']).wont_be_nil
        _(response['progress']['channel']).wont_be_nil
      end
    end

    it 'HAPPY: should queue multiple dish requests in order' do
      header 'CONTENT_TYPE', 'application/json'

      # Create dishes in sequence
      dishes = ['Spaghetti Carbonara', 'Chicken Fried Rice', 'Pizza']
      dishes.each do |dish_name|
        VCR.use_cassette("dish_#{dish_name.downcase.gsub(' ', '_')}") do
          post '/api/v1/dishes', { dish_name: }.to_json
          _(last_response.status).must_equal 202

          response = JSON.parse(last_response.body)
          _(response['status']).must_equal 'processing'
          _(response['data']['dish_name']).must_equal dish_name
          _(response['data']['message_id']).wont_be_nil
          _(response['progress']).wont_be_nil
        end
      end
    end

    it 'HAPPY: should return empty recent dishes for new session' do
      get '/api/v1/dishes'
      _(last_response.status).must_equal 200

      result = JSON.parse(last_response.body)
      _(result['count']).must_equal 0
      _(result['recent_dishes']).must_be_empty
    end

    it 'SAD: should return error for invalid dish data' do
      header 'CONTENT_TYPE', 'application/json'
      post '/api/v1/dishes', { dish_name: '' }.to_json

      _(last_response.status).must_equal 400
      result = JSON.parse(last_response.body)
      _(result['message']).wont_be_nil
    end

    it 'SAD: should return 404 for non-existent dish ID' do
      get '/api/v1/dishes/999999'
      _(last_response.status).must_equal 404
    end
  end

  describe 'Vision API tests' do
    it 'HAPPY: should detect text' do
      image_path = File.join(__dir__, '../../fixtures/text_menu_img.jpeg')
      image_file = Rack::Test::UploadedFile.new(
        image_path,
        'image/jpeg',
        original_filename: 'menu.jpg'
      )

      VCR.use_cassette('menu_text_detection') do
        post '/api/v1/detect_text', { image_file: }
      end

      _(last_response.status).must_equal 200
      result = JSON.parse(last_response.body)
      _(result['status']).must_equal 'ok'
      _(result['data']).wont_be_empty
    end

    it 'SAD: should reject invalid file types' do
      bad_file = Rack::Test::UploadedFile.new(
        StringIO.new('Not an image'),
        'text/plain',
        original_filename: 'not_image.txt'
      )

      post '/api/v1/detect_text', { image_file: bad_file }

      _(last_response.status).must_equal 400
      result = JSON.parse(last_response.body)
      _(result['status']).must_equal 'bad_request'
    end
  end
end
