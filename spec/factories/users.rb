# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "test#{n}@gmail.com" }
    password { 'topsecret' }
    password_confirmation { 'topsecret' }
    first_name { 'John' }
    last_name { 'Doe' }
    timezone { 'Eastern Time (US & Canada)' }
    confirmed_at { Time.now }
    
    trait :confirmed do
      confirmed_at { Time.now }
    end
    
    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :with_two_factor do
      otp_required_for_login { true }
      after(:build) do |user|
        user.otp_secret = User.generate_otp_secret
      end
    end
  end
end
