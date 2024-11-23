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

      routing.on 'api' do
        routing.on 'v1' do
          routing.on 'dishes' do
            # GET /api/v1/dishes/{name} - Get specific dish
            routing.get String do |dish_name|
              begin
                # Validate dish name
                validation = Request::Dish.new.call(dish_name: dish_name)
                if validation.failure?
                  routing.halt(400, { error: 'Invalid dish name', message: validation.errors.to_h })
                end

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

                # Validate request data
                validation = Request::Dish.new.call(dish_name: dish_data['dish_name'])
                if validation.failure?
                  routing.halt(422, { error: 'Invalid request', message: validation.errors.to_h })
                end

                result = Services::CreateDish.new.call(
                  dish_name: validation.to_h[:dish_name],
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
                # Validate dish name
                validation = Request::Dish.new.call(dish_name: dish_name)
                if validation.failure?
                  routing.halt(400, { error: 'Invalid dish name', message: validation.errors.to_h })
                end

                result = Services::RemoveDish.new.call(
                  dish_name: validation.to_h[:dish_name],
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
                # Validate image file
                validation = Request::Image.new.call(image_file: routing.params['image_file'])
                if validation.failure?
                  routing.halt(422, { error: 'Invalid image file', message: validation.errors.to_h })
                end

                result = Services::DetectMenuText.new.call(validation.to_h[:image_file])

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
