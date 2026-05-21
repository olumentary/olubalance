# frozen_string_literal: true

class AssessInterestChargeJob < ApplicationJob
  queue_as :interest

  def perform(account_id, charge_date_iso)
    charge_date = Date.parse(charge_date_iso.to_s)

    ActiveRecord::Base.transaction do
      account = Account.lock.find(account_id)
      return unless account.interest_eligible?
      return unless account.interest_due_on?(charge_date)

      amount = account.monthly_interest_amount
      return if amount <= 0

      category = Category.find_or_create_by!(name: "Interest Charges", kind: :global)

      account.transactions.create!(
        trx_type: "debit",
        amount: amount,
        trx_date: charge_date,
        description: "Interest Charge - #{charge_date.strftime('%B %Y')}",
        category: category
      )

      account.update_column(:last_interest_charged_on, charge_date)
    end
  end
end
