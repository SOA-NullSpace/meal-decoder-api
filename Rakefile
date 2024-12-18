# frozen_string_literal: true

require 'rake'
require 'rake/testtask'
require 'sequel'
require 'fileutils'

# Load application and environment configurations
require_relative 'require_app'

# Helper module for database tasks
module DbHelper
  module_function

  def app
    require_relative 'config/environment'
    require_relative 'spec/helpers/database_helper'
    MealDecoder::App
  end
end

task :default do
  puts `rake -T`
end

# Testing tasks
desc 'Run all tests'
Rake::TestTask.new(:spec) do |t|
  t.libs << 'spec'
  t.pattern = 'spec/tests/**/*_spec.rb'
  t.warning = false
end

desc 'Run integration layer tests'
Rake::TestTask.new(:spec_layers) do |t|
  t.libs << 'spec'
  t.pattern = 'spec/tests/integration/layers/*_spec.rb'
  t.warning = false
end

desc 'Run integration service tests'
Rake::TestTask.new(:spec_services) do |t|
  t.libs << 'spec'
  t.pattern = 'spec/tests/integration/services/*_spec.rb'
  t.warning = false
end

desc 'Run unit tests'
Rake::TestTask.new(:spec_unit) do |t|
  t.libs << 'spec'
  t.pattern = 'spec/tests/unit/**/*_spec.rb'
  t.warning = false
end

desc 'Run acceptance tests'
Rake::TestTask.new(:spec_acceptance) do |t|
  t.libs << 'spec'
  t.pattern = 'spec/tests/acceptance/*_spec.rb'
  t.warning = false
end

# Run all specs
task spec: %i[spec_unit spec_layers spec_services spec_acceptance]

desc 'Keep rerunning tests upon changes'
task :respec do
  sh "rerun -c 'rake spec' --ignore 'coverage/*'"
end

# Application tasks
desc 'Run web app'
task :run do
  sh 'bundle exec puma'
end

desc 'Keep rerunning web app upon changes'
task :rerun do
  sh "rerun -c --ignore 'coverage/*' -- bundle exec puma"
end

# Database tasks
namespace :db do
  desc 'Generates a 64 by secret for Rack::Session'
  task :new_session_secret do
    require 'base64'
    require 'SecureRandom'
    secret = SecureRandom.random_bytes(64).then { Base64.urlsafe_encode64(_1) }
    puts "SESSION_SECRET: #{secret}"
  end

  desc 'Run database migrations'
  task :migrate do
    require_relative 'config/environment'
    Sequel.extension :migration

    environment = ENV['RACK_ENV'] || 'development'
    puts "Migrating #{environment} database"

    Sequel::Migrator.run(MealDecoder::App.db, 'db/migrations')
  end

  desc 'Delete dev/test database file'
  task :drop do
    require_relative 'config/environment'

    if MealDecoder::App.environment == :production
      puts 'Cannot wipe production database!'
      return
    end

    FileUtils.rm(File.expand_path("db/local/#{MealDecoder::App.environment}.db"))
    puts "Deleted #{MealDecoder::App.environment} database"
  end

  desc 'Delete and migrate again'
  task reset: %i[drop migrate]
end

# Console task
desc 'Run application console'
task :console do
  sh 'pry -r ./load_all'
end

# VCR tasks
namespace :vcr do
  desc 'Delete cassette fixtures'
  task :wipe do
    FileUtils.rm_rf('spec/fixtures/cassettes/*.yml')
    puts 'Cassettes deleted'
  end
end

# Quality control tasks
namespace :quality do
  desc 'Run all static-analysis quality checks'
  task all: %i[rubocop reek flog]

  desc 'Code style linter'
  task :rubocop do
    sh 'rubocop'
  end

  desc 'Code smell detector'
  task :reek do
    sh 'reek'
  end

  desc 'Complexity analysis'
  task :flog do
    sh 'flog -m config app'
  end
end

namespace :queues do
  task :config do
    require 'aws-sdk-sqs'
    require_relative 'config/environment'
    @api = MealDecoder::App
    @sqs = Aws::SQS::Client.new(
      access_key_id: @api.config.AWS_ACCESS_KEY_ID,
      secret_access_key: @api.config.AWS_SECRET_ACCESS_KEY,
      region: @api.config.AWS_REGION
    )
    @q_name = @api.config.CLONE_QUEUE

    # Try to fetch queue URL if it exists
    begin
      @q_url = @sqs.get_queue_url(queue_name: @q_name).queue_url
    rescue Aws::SQS::Errors::NonExistentQueue
      # Do nothing if queue doesn't exist yet
      @q_url = nil
    end

    puts "Environment: #{@api.environment}"
    puts "Queue Name: #{@q_name}"
    puts "Region: #{@api.config.AWS_REGION}"
  end

  desc 'Create SQS queue for worker'
  task create: :config do
    if @q_url
      puts "Queue #{@q_name} already exists at #{@q_url}."
    else
      # Create the queue if it doesn't exist
      resp = @sqs.create_queue(queue_name: @q_name)
      @q_url = resp.queue_url

      puts 'Queue created:'
      puts "  Name: #{@q_name}"
      puts "  Region: #{@api.config.AWS_REGION}"
      puts "  URL: #{@q_url}"
    end
  rescue StandardError => e
    puts "Error creating queue: #{e.message}"
  end

  desc 'Report status of queue for worker'
  task status: :config do
    if @q_url
      puts 'Queue info:'
      puts "  Name: #{@q_name}"
      puts "  Region: #{@api.config.AWS_REGION}"
      puts "  URL: #{@q_url}"
    else
      puts "Queue #{@q_name} does not exist. Try running 'rake queues:create' first."
    end
  rescue StandardError => e
    puts "Error checking queue status: #{e.message}"
  end

  desc 'Purge messages in SQS queue for worker'
  task purge: :config do
    if @q_url
      @sqs.purge_queue(queue_url: @q_url)
      puts "Queue #{@q_name} purged."
    else
      puts "Queue #{@q_name} does not exist. Try running 'rake queues:create' first."
    end
  rescue StandardError => e
    puts "Error purging queue: #{e.message}"
  end
end

namespace :worker do
  namespace :run do
    desc 'Run the background cloning worker in development mode'
    task :dev => :config do
      sh 'RACK_ENV=development bundle exec shoryuken -r ./workers/dish_worker.rb -C ./workers/shoryuken_dev.yml'
    end

    desc 'Run the background cloning worker in testing mode'
    task :test => :config do
      sh 'RACK_ENV=test bundle exec shoryuken -r ./workers/dish_worker.rb -C ./workers/shoryuken_test.yml'
    end

    desc 'Run the background cloning worker in production mode'
    task :production => :config do
      sh 'RACK_ENV=production bundle exec shoryuken -r ./workers/dish_worker.rb -C ./workers/shoryuken.yml'
    end
  end
end
