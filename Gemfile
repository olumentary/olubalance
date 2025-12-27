# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

ruby "3.4.8"

gem "aws-sdk-s3"
gem "bootsnap", require: false
gem "bundler", "~> 4.0"
gem "connection_pool", "~> 2.4"
gem "cssbundling-rails"
gem "devise", "~> 4.9.0"
gem "draper", "~> 4.0.2"
gem "faker"
gem "figaro"
gem "hiredis"
gem "image_processing", "~> 1.14.0"
gem "invisible_captcha"
gem "jsbundling-rails"
gem "mini_magick", "~> 5.3.1"
gem "pagy", "~> 9"
gem "pg", "~> 1.6.2"
gem "puma", "~> 7.1"
gem "rails", "~> 8.1"
gem "recaptcha"
gem "ruby-openai", require: "openai"
gem "redis", "~> 5.4.1"
gem "sprockets-rails"
gem "stimulus-rails"
gem "turbo-rails"

group :development, :test do
  gem "benchmark"
  gem "brakeman", require: false
  gem "debug", require: "debug/prelude"
  gem "factory_bot_rails"
  gem "openssl", "~> 4.0.0"
  gem "rails-controller-testing"
  gem "rspec-rails", "~> 8"
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "better_errors"
  gem "binding_of_caller"
  gem "letter_opener"
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "shoulda-matchers", "~> 7.0"
  gem "simplecov", require: false
end
