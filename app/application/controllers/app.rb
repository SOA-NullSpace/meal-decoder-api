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
      response['Content-Type'] = 'application/json'

      routing.root do
        response.status = 200
        { message: 'MealDecoderAPI up at /api/v1' }.to_json
      end

      routing.on 'api' do
        routing.on 'v1' do
          routing.on 'dishes' do
            # GET /api/v1/dishes/{id} - Get dish by ID
            routing.get Integer do |id|
              result = Services::FetchDishById.new.call(id)
              status, body = ResponseHandler.api_response_with_status(result)
              response.status = status
              body
            end

            # GET /api/v1/dishes - Get recent dishes or search by name
            routing.get do
              # If q parameter is present, perform dish search
              if routing.params['q']
                dish_name = routing.params['q']
                result = Services::FetchDish.new.call(dish_name)
                status, body = ResponseHandler.api_response_with_status(result)
                response.status = status
                return body
              end

              # Otherwise return recent dishes
              response.status = 200
              dish_names = session[:searched_dishes] || []
              recent_dishes = []

              dish_names.each do |name|
                dish = Services::FetchDish.new.call(name)
                recent_dishes << dish.value! if dish.success?
              end

              {
                count: recent_dishes.length,
                recent_dishes: recent_dishes.map(&:to_h)
              }.to_json
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
                {
                  status: api_result.status,
                  message: api_result.message,
                  data: api_result.data
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
            result = Services::DetectMenuText.new.call(routing.params['image_file'])

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
