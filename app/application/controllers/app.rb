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
      { error: 'Internal Server Error', message: error.message }
    end

    route do |routing|
      response['Content-Type'] = 'application/json'

      # GET /api/v1/dishes - List dishes from search history
      routing.on 'api' do
        routing.on 'v1' do
          routing.on 'dishes' do
            # GET /api/v1/dishes
            routing.get String do |dish_name|
          begin
            # Normalize the dish name before lookup
            puts "GET request for dish: #{dish_name}"
            result = Services::FetchDish.new.call(dish_name)

            case result
            when Success
              {
                status: 'success',
                data: {
                  name: result.value!.name,
                  ingredients: result.value!.ingredients,
                  total_calories: result.value!.total_calories,
                  calorie_level: result.value!.calorie_level
                }
              }
            when Failure
              routing.halt(404, { error: result.failure })
            end
          rescue StandardError => e
            puts "API ERROR: #{e.message}"
            routing.halt(500, { error: 'API Error', message: e.message })
          end
        end

        # GET /api/v1/dishes - List all dishes
        routing.get do
          begin
            result = Services::ListDishes.new.call

            case result
            when Success
              {
                status: 'success',
                data: result.value!.map { |dish|
                  {
                    name: dish.name,
                    ingredients: dish.ingredients,
                    total_calories: dish.total_calories,
                    calorie_level: dish.calorie_level
                  }
                }
              }
            when Failure
              routing.halt(404, { error: result.failure })
            end
          rescue StandardError => e
            puts "API ERROR: #{e.message}"
            routing.halt(500, { error: 'API Error', message: e.message })
          end
        end

        # POST /api/v1/dishes - Create new dish
        routing.post do
          begin
            dish_data = JSON.parse(routing.body.read)
            result = Services::CreateDish.new.call(
              dish_name: dish_data['dish_name'],
              session: {}
            )

            case result
            when Success
              response.status = 201
              dish = result.value!
              {
                status: 'success',
                message: 'Dish created successfully',
                data: {
                  name: dish.name,
                  ingredients: dish.ingredients,
                  total_calories: dish.total_calories,
                  calorie_level: dish.calorie_level
                }
              }
            when Failure
              routing.halt(422, { error: result.failure })
            end
          rescue StandardError => e
            puts "API ERROR: #{e.message}"
            routing.halt(500, { error: 'API Error', message: e.message })
          end
        end

            # DELETE /api/v1/dishes/{name}
            routing.delete String do |dish_name|
              begin
                result = Services::RemoveDish.new.call(
                  dish_name: dish_name,
                  session: {}
                )

                case result
                when Success
                  response.status = 200
                  { status: 'success', message: 'Dish removed successfully' }
                when Failure
                  routing.halt(404, { error: result.failure })
                end
              rescue StandardError => e
                puts "API ERROR: #{e.message}"
                routing.halt(500, { error: 'API Error', message: e.message })
              end
            end
          end

          # POST /api/v1/detect_text
          routing.on 'detect_text' do
            routing.post do
              begin
                # TODO: Update to handle direct file upload in API context
                result = Services::DetectMenuText.new.call(routing.params['image_file'])

                case result
                when Success
                  {
                    status: 'success',
                    data: { detected_text: result.value! }
                  }
                when Failure
                  routing.halt(422, { error: result.failure })
                end
              rescue StandardError => e
                puts "API ERROR: #{e.message}"
                routing.halt(500, { error: 'API Error', message: e.message })
              end
            end
          end
        end
      end
    end
  end
end
