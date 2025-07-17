# frozen_string_literal: true

FactoryBot.define do
  factory :transaction do
    trx_date { Date.today }
    description { 'Test Transaction' }
    amount { Faker::Number.decimal(l_digits: 3, r_digits: 2) }
    trx_type { 'debit' }
    memo { 'Sample Memo' }
    association :account

    trait :credit_transaction do
      trx_type { 'credit' }
    end

    trait :non_pending do
      skip_pending_default { true }
    end
  end
end
