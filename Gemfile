source "https://rubygems.org"

# Specify Ruby version
ruby "3.3.0"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.4"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.5"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Redis for caching
gem "redis", ">= 4.0.1"
gem "connection_pool", "~> 2.4"

# JSON API
gem "jsonapi-serializer"

# Background jobs - using Sidekiq instead of Solid Queue for more features
gem "sidekiq", "~> 7.0"

# Pagination
gem "kaminari", "~> 1.2"

# Money handling for multi-currency support
gem "money-rails", "~> 1.15"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS)
gem "rack-cors"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # RSpec for testing
  gem "rspec-rails", "~> 7.0"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.2"
  gem "database_cleaner-active_record", "~> 2.1"
  gem "dotenv-rails"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Both annotate and bullet don't support Rails 8 yet - removed for now
end

group :test do
  gem "shoulda-matchers", "~> 6.0"
  gem "simplecov", require: false
end