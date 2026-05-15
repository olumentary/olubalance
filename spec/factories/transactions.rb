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

    # A pending quick-receipt (mobile capture) row with no description/amount —
    # mirrors how QuickTransactionsController#create persists a placeholder
    # before the user fills in the details. Saved with `validate: false` to
    # bypass the description/amount presence checks the controller bypasses too.
    trait :quick_receipt do
      quick_receipt { true }
      pending { true }
      description { nil }
      amount { nil }
      to_create { |instance| instance.save!(validate: false) }
    end
  end
end
