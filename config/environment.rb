# frozen_string_literal: true

require 'figaro'
require 'roda'
require 'sequel'
require 'yaml'
require 'rack/method_override'
require 'rack/session'
require 'rack'

module MealDecoder
  # Configuration for the App
  class App < Roda
    # Environment variables setup using Figaro
    env = ENV['RACK_ENV'] || 'development'
    Figaro.application = Figaro::Application.new(
      environment: env,
      path: File.expand_path('config/secrets.yml')
    )
    Figaro.load

    def self.config = Figaro.env

    plugin :environments
    plugin :all_verbs
    plugin :common_logger, $stderr
    plugin :flash
    plugin :public, root: 'app/presentation/assets'
    plugin :sessions,
           key: 'meal_decoder.session',
           secret: config.SESSION_SECRET,
           cookie_options: {
             max_age: 86_400 # 1 day in seconds
           }

    # Set API_HOST based on the environment
    @@api_host = ENV['RACK_ENV'] == 'production' ? 'https://your-production-url.com' : 'http://localhost:9292'

    def self.api_host
      @@api_host
    end

    configure do
      use Rack::MethodOverride
      use Rack::Session::Cookie,
          key: 'rack.session',
          secret: config.SESSION_SECRET,
          same_site: :strict
    end

    configure :development, :test do
      require 'pry'
      # Make sure the db directory exists
      db_path = File.expand_path("db/local/#{environment}.db")
      FileUtils.mkdir_p(File.dirname(db_path))
      ENV['DATABASE_URL'] = "sqlite://#{db_path}"
    end

    configure :production do
      # Use DATABASE_URL from environment
    end

    # Database Setup
    DB = Sequel.connect(ENV.fetch('DATABASE_URL'))
    def self.db = DB

    # Load all application files
    def self.setup_application!
      Sequel.extension :migration
      db.extension :freeze_datasets if env == 'production'

      # Run migrations if in development/test
      return unless %w[development test].include?(env)

      Sequel::Migrator.run(db, 'db/migrations') if db.tables.empty?
    end
  end
end
