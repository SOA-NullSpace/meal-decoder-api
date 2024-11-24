# frozen_string_literal: true

require 'roda'
require 'json'
require 'dry/monads'

module MealDecoder
  # Web API
  class App < Roda
    plugin :all_verbs
    plugin :request_headers
    plugin :halt
    plugin :json
    plugin :error_handler

    error do |e|
      puts "ERROR: #{e.inspect}"
      response.status = 500
      { message: e.message }.to_json
    end

    route do |routing|
      response['Content-Type'] = 'application/json'

      routing.root do
        response.status = 200
        { message: 'MealDecoderAPI up at /api/v1' }.to_json
      end

      routing.on 'api' do
        routing.on 'v1' do
          routing.on 'dishes' do
            # POST /api/v1/dishes
            routing.post do
              begin
                request_data = JSON.parse(routing.body.read)
                result = Services::CreateDish.new.call(
                  dish_name: request_data['dish_name'],
                  session: {}
                )

                if result.is_a?(Dry::Monads::Success)
                  response.status = 200
                  result.value!.to_h.to_json
                else
                  response.status = 400
                  { message: result.failure }.to_json
                end
              rescue JSON::ParserError
                response.status = 400
                { message: 'Invalid JSON format' }.to_json
              end
            end

            # GET /api/v1/dishes/{name}
            routing.get String do |dish_name|
              result = Services::FetchDish.new.call(dish_name)

              if result.is_a?(Dry::Monads::Success)
                response.status = 200
                result.value!.to_h.to_json
              else
                response.status = 404
                { message: result.failure }.to_json
              end
            end

            # DELETE /api/v1/dishes/{name}
            routing.delete String do |dish_name|
              result = Services::RemoveDish.new.call(
                dish_name: dish_name,
                session: {}
              )

              if result.is_a?(Dry::Monads::Success)
                response.status = 200
                { message: "Dish deleted" }.to_json
              else
                response.status = 404
                { message: result.failure }.to_json
              end
            end
          end

          # POST /api/v1/detect_text
          routing.post 'detect_text' do
            result = Services::DetectMenuText.new.call(routing.params['image_file'])

            if result.is_a?(Dry::Monads::Success)
              response.status = 200
              {
                status: 'ok',
                message: 'Text detected',
                data: result.value!
              }.to_json
            else
              response.status = 400
              {
                status: 'bad_request',
                message: result.failure
              }.to_json
            end
          end
        end
      end
    end
  end
end
