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

    trait :admin do
      admin { true }
    end

    # Creates a user with one confirmed authenticator. `authenticator_secret`
    # is exposed as a transient so specs can compute matching OTP codes.
    trait :with_two_factor do
      transient do
        authenticator_nickname { "Test Phone" }
      end

      after(:create) do |user, evaluator|
        user.authenticators.create!(
          nickname:     evaluator.authenticator_nickname,
          otp_secret:   Authenticator.generate_secret,
          confirmed_at: Time.current
        )
      end
    end
  end
end
