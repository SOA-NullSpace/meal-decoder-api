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
    it 'HAPPY: should create a dish and show in recent dishes' do
      # Create first dish
      header 'CONTENT_TYPE', 'application/json'
      dish_data = { dish_name: 'Spaghetti Carbonara' }.to_json

      VCR.use_cassette('dish_carbonara') do
        post '/api/v1/dishes', dish_data
        _(last_response.status).must_equal 200
      end

      # Create second dish
      dish_data = { dish_name: 'Chicken Fried Rice' }.to_json
      VCR.use_cassette('dish_fried_rice') do
        post '/api/v1/dishes', dish_data
        _(last_response.status).must_equal 200
      end

      # Get recent dishes
      get '/api/v1/dishes'
      _(last_response.status).must_equal 200

      result = JSON.parse(last_response.body)
      _(result['count']).must_equal 2

      recent_dishes = result['recent_dishes']
      _(recent_dishes).must_be_kind_of Array
      _(recent_dishes.map { |d| d['name'] }).must_include 'Spaghetti Carbonara'
      _(recent_dishes.map { |d| d['name'] }).must_include 'Chicken Fried Rice'
    end

    it 'HAPPY: should maintain dish order in recent dishes' do
      header 'CONTENT_TYPE', 'application/json'

      # Create dishes in sequence
      dishes = ['Spaghetti Carbonara', 'Chicken Fried Rice', 'Pizza']
      dishes.each do |dish_name|
        VCR.use_cassette("dish_#{dish_name.downcase.gsub(' ', '_')}") do
          post '/api/v1/dishes', { dish_name: }.to_json
          _(last_response.status).must_equal 200
        end
      end

      # Get recent dishes
      get '/api/v1/dishes'
      result = JSON.parse(last_response.body)
      recent_dishes = result['recent_dishes']

      # Verify order (most recent first)
      _(recent_dishes.map { |d| d['name'] }).must_equal dishes.reverse
    end

    it 'HAPPY: should return empty recent dishes for new session' do
      get '/api/v1/dishes'
      _(last_response.status).must_equal 200

      result = JSON.parse(last_response.body)
      _(result['count']).must_equal 0
      _(result['recent_dishes']).must_be_empty
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
