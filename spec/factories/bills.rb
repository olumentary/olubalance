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
    biweekly_mode { nil }
    second_day_of_month { nil }
    biweekly_anchor_weekday { nil }
    biweekly_anchor_date { nil }
    next_occurrence_month { nil }
    amount { Faker::Number.decimal(l_digits: 3, r_digits: 2) }
    notes { 'Sample bill notes' }

    trait :income do
      bill_type { 'income' }
      category { 'income' }
    end

    trait :annual do
      frequency { 'annual' }
      next_occurrence_month { Date.current.month }
    end

    trait :bi_weekly do
      frequency { 'bi_weekly' }
      biweekly_mode { 'every_other_week' }
      biweekly_anchor_date { Date.current }
      biweekly_anchor_weekday { Date.current.wday }
    end

    trait :bi_weekly_two_days do
      frequency { 'bi_weekly' }
      biweekly_mode { 'two_days' }
      second_day_of_month { 30 }
    end

    trait :quarterly do
      frequency { 'quarterly' }
      next_occurrence_month { Date.current.month }
    end
  end
end

