# frozen_string_literal: true

FactoryBot.define do
  factory :bill do
    association :account
    user { account.user }
    bill_type { 'expense' }
    category { 'housing' }
    description { 'Sample Bill' }
    frequency { 'monthly' }
    day_of_month { 15 }
    amount { Faker::Number.decimal(l_digits: 3, r_digits: 2) }
    notes { 'Sample bill notes' }

    trait :income do
      bill_type { 'income' }
      category { 'income' }
    end

    trait :annual do
      frequency { 'annual' }
    end

    trait :bi_weekly do
      frequency { 'bi_weekly' }
    end
  end
end

