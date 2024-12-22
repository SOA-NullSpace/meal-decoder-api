# frozen_string_literal: true

module MealDecoder
  # Web API
  class App < Roda
    plugin :all_verbs
    plugin :request_headers
    plugin :halt
    plugin :json
    plugin :error_handler
    plugin :request_headers
    plugin :cookies
    plugin :sessions,
           key: 'meal_decoder.session',
           secret: config.SESSION_SECRET

    # Response handler for consistent API responses
    class ResponseHandler
      # Encapsulates HTTP response data including status code and body
      # Provides a consistent structure for all API responses
      Response = Struct.new(:status, :body) do
        def to_json_response
          [status, body.to_json]
        end
      end

      # Formats different types of values into consistent response structures
      class SuccessFormatter
        def self.format(value)
          new(value).formatted_response
        end

        def initialize(value)
          @value = value
          @formatters = [HashFormatter, DryStructFormatter, DefaultFormatter]
        end

        def formatted_response
          current_formatter = @formatters.find { |fmt| fmt.handles?(@value) }
          current_formatter.format(@value)
        end

        # Handles pure Hash objects
        class HashFormatter
          def self.handles?(value)
            value.instance_of?(Hash)
          end

          def self.format(value)
            value
          end
        end

        # Handles Dry::Struct and other objects with to_h
        class DryStructFormatter
          EXCLUDED_TYPES = [String].freeze

          def self.handles?(value)
            return true if value.is_a?(Dry::Struct)
            return false if excluded_type?(value)

            value.class.instance_methods(false).include?(:to_h)
          end

          def self.format(value)
            value.to_h
          end

          def self.excluded_type?(value)
            EXCLUDED_TYPES.any? { |type| value.instance_of?(type) }
          end
        end

        # Handles all other types
        class DefaultFormatter
          def self.handles?(_value)
            true
          end

          def self.format(value)
            { message: value.to_s }
          end
        end
      end

      def self.api_response(result)
        response = handle_result(result, 200, 400)
        response.to_json_response
      end

      def self.api_response_with_status(result, success_status: 200, error_status: 404)
        response = handle_result(result, success_status, error_status)
        response.to_json_response
      end

      def self.json_response(data, status = 200)
        Response.new(status, data).to_json_response
      end

      private_class_method def self.handle_result(result, success_status, error_status)
        if result.success?
          handle_success(result.value!, success_status)
        else
          handle_error(result.failure, error_status)
        end
      end

      private_class_method def self.handle_success(value, status)
        Response.new(status, SuccessFormatter.format(value))
      end

      private_class_method def self.handle_error(error, status)
        Response.new(status, { message: error })
      end
    end

    error do |error|
      puts "ERROR: #{error.inspect}"
      response.status = 500
      { message: error.message }.to_json
    end

    route do |routing|
      response['Content-Type'] = 'application/json; charset=utf-8'

      # Handle Faye WebSocket requests
      routing.on 'faye' do
        # Faye middleware handles these requests
        pass
      end

      routing.root do
        response.status = 200
        { message: 'MealDecoderAPI up at /api/v1' }.to_json
      end

      routing.on 'api' do
        routing.on 'v1' do
          routing.on 'dishes' do
            routing.get 'status', String do |message_id|
              result = Services::FetchDishStatus.new.call(message_id)
              status, body = ResponseHandler.api_response_with_status(result)
              response.status = status
              body
            end

            # GET /api/v1/dishes/{id} - Get dish by ID
            routing.get Integer do |id|
              result = Services::FetchDishById.new.call(id)
              status, body = ResponseHandler.api_response_with_status(result)
              response.status = status
              body
            end

            # GET /api/v1/dishes - Get recent dishes or search by name
            routing.get do
              dishes = Repository::For.klass(Entity::Dish).all
              puts "Found #{dishes.length} dishes in database"

              response.status = 200
              {
                count: dishes.length,
                recent_dishes: dishes.map do |dish|
                  puts "Processing dish: #{dish.name} (Status: #{dish.status})"
                  # Include all dishes, but with appropriate status
                  dish_data = dish.to_h
                  dish_data[:status] = dish.status
                  dish_data
                end
              }.to_json
            rescue StandardError => e
              puts "Error fetching dishes: #{e.message}"
              puts e.backtrace
              response.status = 500
              { message: "Error fetching dishes: #{e.message}" }.to_json
            end

            # POST /api/v1/dishes
            routing.post do
              request_data = parse_json_request(routing.body.read)
              result = Services::CreateDish.new.call(
                dish_name: request_data['dish_name'],
                session:
              )

              if result.success?
                api_result = result.value!
                # If the status is :processing, return 202 Accepted
                response.status = api_result.status == :processing ? 202 : 201

                # Create an initial database record
                dish = Repository::For.klass(Entity::Dish).create(
                  Entity::Dish.new(
                    id: nil,
                    name: request_data['dish_name'],
                    ingredients: [],
                    status: 'processing',
                    message_id: api_result.data[:message_id]
                  )
                )

                channel_id = api_result.data[:channel_id]
                {
                  status: api_result.status,
                  message: api_result.message,
                  data: api_result.data.merge(
                    dish_id: dish&.id
                  ),
                  progress: {
                    channel: "/progress/#{channel_id}",
                    endpoint: "#{App.api_host}/faye"
                  }
                }.to_json
              else
                response.status = 400
                { message: result.failure }.to_json
              end
            end

            # DELETE /api/v1/dishes/{id}
            routing.delete Integer do |id|
              result = Services::RemoveDish.new.call(
                dish_id: id,
                session:
              )

              session[:searched_dishes]&.delete(result.value!.name) if result.success? && result.value!.name

              status, body = ResponseHandler.api_response_with_status(
                result,
                success_status: 200,
                error_status: 404
              )
              response.status = status
              body
            end
          end

          # POST /api/v1/detect_text
          routing.post 'detect_text' do
            translate = routing.params['translate']&.downcase == 'true'
            result = Services::DetectMenuText.new.call(
              routing.params['image_file'],
              translate:
            )

            status, body = if result.success?
                             [200, {
                               status: 'ok',
                               message: 'Text detected',
                               data: result.value!
                             }]
                           else
                             [400, {
                               status: 'bad_request',
                               message: result.failure
                             }]
                           end

            response.status = status
            body.to_json
          end
        end
      end
    end

    private

    def parse_json_request(body)
      JSON.parse(body)
    rescue JSON::ParserError
      response.status = 400
      raise StandardError, 'Invalid JSON format'
    end
  end
end
