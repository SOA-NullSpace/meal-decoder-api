# frozen_string_literal: true

require 'roda'
require 'json'
require 'rack'
require 'dry/monads'

module MealDecoder
  # Web API
  class App < Roda
    include Dry::Monads[:result]

    plugin :environments
    plugin :all_verbs
    plugin :request_headers
    plugin :halt
    plugin :json
    plugin :error_handler

    # Handle all errors
    error do |error|
      puts "ERROR: #{error.inspect}"
      puts error.backtrace

      response.status = 500
      response_json = Representer::HttpResponse.new(Response::ApiResult.new(
                                                      status: :internal_error,
                                                      message: error.message
                                                    )).to_json
      response['Content-Type'] = 'application/json'
      response.write(response_json)
    end

    route do |routing|
      response['Content-Type'] = 'application/json'

      routing.on 'api' do
        routing.on 'v1' do
          routing.on 'dishes' do
            # GET /api/v1/dishes/{name} - Get specific dish
            routing.get String do |dish_name|
              result = Services::FetchDish.new.call(dish_name)
              handle_result(result, Representer::Dish)
            end

            # GET /api/v1/dishes - List all dishes
            routing.get do
              result = Services::ListDishes.new.call
              handle_result(result, Representer::DishList)
            end

            # POST /api/v1/dishes - Create new dish
            routing.post do
              dish_data = JSON.parse(routing.body.read)
              result = Services::CreateDish.new.call(
                dish_name: dish_data['dish_name'],
                session: {}
              )
              handle_result(result, Representer::Dish)
            end

            # DELETE /api/v1/dishes/{name}
            routing.delete String do |dish_name|
              result = Services::RemoveDish.new.call(
                dish_name:,
                session: {}
              )
              handle_result(result)
            end
          end

          # POST /api/v1/detect_text
          routing.on 'detect_text' do
            routing.post do
              result = Services::DetectMenuText.new.call(routing.params['image_file'])
              handle_result(result, Representer::MenuText)
            end
          end
        end
      end
    end

    private

    def handle_result(result, representer = nil)
      case result
      when Success
        response.status = 200
        if representer
          representer.new(result.value!).to_json
        else
          Representer::HttpResponse.new(Response::ApiResult.new(
                                          status: :ok,
                                          message: 'Success',
                                          data: result.value!
                                        )).to_json
        end
      when Failure
        api_result = Response::ApiResult.new(
          status: :bad_request,
          message: result.failure
        )
        http_response = Representer::HttpResponse.new(api_result)
        response.status = http_response.http_status_code
        http_response.to_json
      end
    end
  end
end
