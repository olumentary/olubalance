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
  end
end
