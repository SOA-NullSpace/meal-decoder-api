# frozen_string_literal: true

require 'roda'
require 'slim'
require 'rack'
require 'dry/monads'

module MealDecoder
  # Web App
  class App < Roda
    include Dry::Monads[:result]

    plugin :environments
    plugin :render, engine: 'slim', views: 'app/presentation/views_html'
    plugin :public, root: 'app/presentation/assets'
    plugin :static, ['/assets']
    plugin :flash
    plugin :all_verbs
    plugin :request_headers
    plugin :common_logger, $stderr
    plugin :halt
    plugin :error_handler

    use Rack::MethodOverride

    # Handle all errors
    error do |error|
      puts "ERROR: #{error.inspect}"
      puts error.backtrace
      flash[:error] = 'An unexpected error occurred'
      response.status = 500
      routing.redirect '/'
    end

    route do |routing|
      response['Content-Type'] = 'text/html; charset=utf-8'
      routing.public

      # GET / - Home page with search history
      routing.root do
        # Ensure session exists
        session[:searched_dishes] ||= []
        puts "ROOT - Session before processing: #{session[:searched_dishes].inspect}"

        begin
          # Load dishes from search history
          dishes = session[:searched_dishes].map do |dish_name|
            puts "Attempting to fetch dish: #{dish_name}"
            result = Services::FetchDish.new.call(dish_name)
            result.value_or(nil)
          end.compact

          # Update session with valid dishes
          session[:searched_dishes] = dishes.map(&:name)
          puts "ROOT - Session after processing: #{session[:searched_dishes].inspect}"

          # Render view
          view 'home', locals: {
            title_suffix: 'Home',
            dishes: Views::DishesList.new(dishes)
          }
        rescue StandardError => e
          puts "ROOT ERROR: #{e.message}"
          flash.now[:error] = 'Having trouble accessing the database'
          view 'home', locals: {
            title_suffix: 'Home',
            dishes: Views::DishesList.new([])
          }
        end
      end

      # POST /fetch_dish - Create or retrieve dish information
      routing.on 'fetch_dish' do
        routing.post do
          puts "FETCH - Session before processing: #{session[:searched_dishes].inspect}"

          form = Forms::NewDish.new.call(routing.params)
          if form.failure?
            flash[:error] = form.errors.messages.first.text
            routing.redirect '/'
          end

          result = Services::CreateDish.new.call(
            dish_name: form.to_h[:dish_name],
            session:
          )

          case result
          when Success
            dish = result.value!
            # Ensure the dish is added to session
            session[:searched_dishes] ||= []
            session[:searched_dishes].unshift(dish.name)
            session[:searched_dishes].uniq!

            puts "FETCH - Session after processing: #{session[:searched_dishes].inspect}"

            flash[:success] = 'Successfully added new dish!'
            routing.redirect "/display_dish?name=#{CGI.escape(dish.name)}"
          when Failure
            flash[:error] = result.failure
            routing.redirect '/'
          end
        end
      end

      # GET /display_dish - Show detailed dish information
      routing.on 'display_dish' do
        routing.get do
          # Step 1: Extract and validate dish name
          dish_name = CGI.unescape(routing.params['name'].to_s)
          unless dish_name && !dish_name.empty?
            flash[:error] = 'Could not find that dish'
            routing.redirect '/'
          end

          # Step 2: Fetch dish from database
          result = Services::FetchDish.new.call(dish_name)

          # Step 3: Process the result
          case result
          when Success
            # Step 4a: Display dish information
            view 'dish', locals: {
              title_suffix: result.value!.name,
              dish: Views::Dish.new(result.value!)
            }
          when Failure
            # Step 4b: Handle missing dish
            flash[:error] = result.failure
            routing.redirect '/'
          end
        rescue StandardError => e
          puts "DISPLAY DISH ERROR: #{e.message}"
          flash[:error] = 'Error occurred while retrieving dish information'
          routing.redirect '/'
        end
      end

      # POST /detect_text - Process menu image
      routing.on 'detect_text' do
        routing.post do
          # Step 1: Validate uploaded file
          upload_form = Forms::ImageFileUpload.new.call(routing.params)
          if upload_form.failure?
            flash[:error] = upload_form.errors.messages.first.text
            routing.redirect '/'
          end

          # Step 2: Process image with Google Vision API
          result = Services::DetectMenuText.new.call(upload_form.to_h[:image_file])

          # Step 3: Handle the result
          case result
          when Success
            # Step 4a: Display detected text
            view 'display_text', locals: {
              title_suffix: 'Text Detection',
              text: Views::TextDetection.new(result.value!)
            }
          when Failure
            # Step 4b: Handle text detection failure
            flash[:error] = result.failure
            routing.redirect '/'
          end
        rescue StandardError => e
          puts "TEXT DETECTION ERROR: #{e.message}"
          flash[:error] = 'Error occurred while processing the image'
          routing.redirect '/'
        end
      end

      # DELETE /dish/{name} - Remove dish from history
      routing.on 'dish', String do |encoded_dish_name|
        routing.delete do
          # Step 1: Decode dish name
          dish_name = CGI.unescape(encoded_dish_name)

          # Step 2: Remove dish from history and database
          result = Services::RemoveDish.new.call(
            dish_name:,
            session:
          )

          # Step 3: Handle the result
          case result
          when Success
            flash[:success] = 'Dish removed from history'
          when Failure
            flash[:error] = result.failure
          end
        rescue StandardError => e
          puts "DELETE DISH ERROR: #{e.message}"
          flash[:error] = 'Error occurred while removing dish'
        ensure
          # Always redirect to home page
          routing.redirect '/'
        end
      end
    end
  end
end
