# frozen_string_literal: true

FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Test Account #{n}" }
    starting_balance { Faker::Number.decimal(l_digits: 4, r_digits: 2) }
    last_four { 1234 }
    active { true }
    account_type { 'checking' }
    association :user

    trait :checking do
      account_type { 'checking' }
    end

    trait :credit do
      account_type { 'credit' }
      interest_rate { Faker::Number.between(from: 10.00, to: 25.00).to_f.round(2) }
      credit_limit { Faker::Number.between(from: 3000.00, to: 20000.00).to_f.round(2) }
      statement_day { 15 }
    end

    trait :savings do
      account_type { 'savings' }
      interest_rate { Faker::Number.between(from: 0.50, to: 1.00).to_f.round(2) }
    end

    trait :cash do
      account_type { 'cash' }
    end
  end
end
