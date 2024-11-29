# frozen_string_literal: true

require_relative '../../spec_helper'

def app
  MealDecoder::App
end

describe 'API acceptance tests' do
  include Rack::Test::Methods
  include MiniTestSetup

  before do
    DatabaseHelper.wipe_database
    @config = OpenStruct.new(
      OPENAI_API_KEY: OPENAI_API_KEY,
      GOOGLE_CLOUD_API_TOKEN: GOOGLE_CLOUD_API_TOKEN
    )
    VcrHelper.configure_vcr_for_apis(@config)
  end

  describe 'Dish API tests' do
    it 'HAPPY: should create a dish' do
      # Create dish with known ingredients
      dish_data = { dish_name: 'Spaghetti Carbonara' }.to_json
      header 'CONTENT_TYPE', 'application/json'

      VCR.use_cassette('dish_carbonara') do
        post '/api/v1/dishes', dish_data

        _(last_response.status).must_equal 200

        result = JSON.parse(last_response.body)
        _(result['name']).must_equal 'Spaghetti Carbonara'
        _(result['ingredients']).must_be_kind_of Array
        _(result['ingredients']).must_include 'Spaghetti'
      end
    end

    it 'HAPPY: should retrieve a dish with spaces in name' do
      # First, create a test dish with spaces
      dish = MealDecoder::Entity::Dish.new(
        id: nil,
        name: 'Chicken Fried Rice',
        ingredients: %w[chicken rice]
      )
      stored_dish = MealDecoder::Repository::For.entity(dish).create(dish)

      # Test retrieving the dish using the query parameter
      get "/api/v1/dishes?q=#{CGI.escape(stored_dish.name)}"
      _(last_response.status).must_equal 200

      result = JSON.parse(last_response.body)
      _(result['name']).must_equal 'Chicken Fried Rice'
    end

    it 'HAPPY: should delete a dish by ID' do
      # First, create a test dish
      dish = MealDecoder::Entity::Dish.new(
        id: nil,
        name: 'TestDish',
        ingredients: ['test ingredient']
      )
      stored_dish = MealDecoder::Repository::For.entity(dish).create(dish)

      delete "/api/v1/dishes/#{stored_dish.id}"
      _(last_response.status).must_equal 200

      # Verify the dish is gone
      get "/api/v1/dishes?q=#{CGI.escape(stored_dish.name)}"
      _(last_response.status).must_equal 404
    end

    it 'SAD: should return error for non-existent dish ID' do
      delete '/api/v1/dishes/999999'
      _(last_response.status).must_equal 404

      result = JSON.parse(last_response.body)
      _(result['message']).must_include 'Could not find dish with ID'
    end

    it 'SAD: should return error for non-existent dish name' do
      get '/api/v1/dishes?q=nonexistentdish'
      _(last_response.status).must_equal 404
    end

    it 'SAD: should return error for missing dish name parameter' do
      get '/api/v1/dishes'
      _(last_response.status).must_equal 200

      result = JSON.parse(last_response.body)
      _(result['message']).must_equal 'Missing dish name parameter'
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
