# frozen_string_literal: true

FactoryBot.define do
  factory :bill_transaction_batch do
    association :user
    period_month { Date.current.beginning_of_month }
    transactions_count { 0 }
    total_amount { BigDecimal("0") }
  end
end
