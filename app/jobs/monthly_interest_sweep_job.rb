# frozen_string_literal: true

class MonthlyInterestSweepJob < ApplicationJob
  queue_as :interest

  def perform(today = nil)
    today = today.is_a?(Date) ? today : (today.present? ? Date.parse(today.to_s) : Date.current)

    Account.where(account_type: :credit, active: true).find_each do |account|
      next unless account.interest_eligible?
      next unless account.interest_due_on?(today)

      AssessInterestChargeJob.perform_later(account.id, today.to_s)
    end
  end
end
