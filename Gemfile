# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

ruby "3.4.5"

gem "aws-sdk-s3"
gem "bootsnap", require: false
gem "cssbundling-rails"
gem "devise", "~> 4.9.0"
gem "draper", "~> 4.0.2"
gem "faker"
gem "figaro"
gem "hiredis"
gem "image_processing", "~> 1.12.2"
gem "invisible_captcha"
gem "jsbundling-rails"
gem "mini_magick", "~> 4.12.0"
gem "pagy", "~> 9"
gem "pg", "~> 1.5.4"
gem "puma", "~> 6.4.2"
gem "rails", "~> 8.0"
gem "recaptcha"
gem "redis", "~> 4.4.0", require: [ "redis", "redis/connection/hiredis" ]
gem "sprockets-rails"
gem "stimulus-rails"
gem "turbo-rails"

group :development, :test do
  gem "brakeman", require: false
  gem "debug", require: "debug/prelude"
  gem "factory_bot_rails"
  gem "rails-controller-testing"
  gem "rspec-rails", "~> 7.0.0"
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
  gem "shoulda-matchers", "~> 6.0"
  gem "simplecov", require: false
end
