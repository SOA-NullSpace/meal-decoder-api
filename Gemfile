# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.3.5'

gem 'ostruct', '0.6.0'

# gem "rails"
gem 'pry'
gem 'rake', '13.2'

gem 'dry-struct', '1.6'
gem 'dry-types', '1.7'

# Networking
gem 'http', '5.2'

# PRESENTATION LAYER
gem 'multi_json', '1.15'
gem 'roar', '1.2'

# Web Application
gem 'logger', '1.6'
gem 'puma', '6.4'
gem 'rack', '3.1'
gem 'rack-session'
gem 'roda', '3.85'
gem 'slim', '5.2'

# Controllers and services
gem 'dry-monads', '1.6'
gem 'dry-transaction', '0.16.0'
gem 'dry-validation', '1.10'

gem 'figaro'

# Database
gem 'hirb'
# gem 'hirb-unicode' # incompatible with new rubocop
gem 'sequel', '5.85'

group :development, :test do
  gem 'sqlite3', '1.7'
end

group :production do
  gem 'pg'
end

# Asynchronicity
gem 'aws-sdk-sqs', '1.89'
gem 'shoryuken', '6.2'

# Testing
group :test do
  gem 'minitest', '5.25'
  gem 'minitest-rg', '5.3'
  gem 'rack-test', '2.1'
  gem 'simplecov', '0.22.0'
  gem 'vcr', '6.3'
  gem 'webmock', '3.24'
end

# Development
group :development do
  gem 'flog'
  gem 'reek'
  gem 'rerun'
  gem 'rubocop'
  gem 'rubocop-minitest'
  gem 'rubocop-rake'
  gem 'rubocop-sequel'
end
