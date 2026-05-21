# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonthlyInterestSweepJob, type: :job do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { FactoryBot.create(:user) }
  let(:today) { Date.new(2026, 5, 15) }

  let!(:due_credit) do
    FactoryBot.create(:account, :credit,
                      user: user,
                      starting_balance: -500,
                      statement_day: 15,
                      interest_rate: 24.0)
  end

  let!(:not_due_credit) do
    FactoryBot.create(:account, :credit,
                      user: user,
                      starting_balance: -500,
                      statement_day: 20,
                      interest_rate: 24.0)
  end

  let!(:positive_balance_credit) do
    FactoryBot.create(:account, :credit,
                      user: user,
                      starting_balance: 100,
                      statement_day: 15,
                      interest_rate: 24.0)
  end

  let!(:checking) { FactoryBot.create(:account, :checking, user: user) }

  it "enqueues an AssessInterestChargeJob only for due, eligible credit accounts" do
    expect {
      described_class.new.perform(today)
    }.to have_enqueued_job(AssessInterestChargeJob).with(due_credit.id, today.to_s).exactly(:once)
  end

  it "does not enqueue for accounts whose statement_day does not match today" do
    expect {
      described_class.new.perform(today)
    }.not_to have_enqueued_job(AssessInterestChargeJob).with(not_due_credit.id, anything)
  end

  it "does not enqueue for credit accounts with non-negative balance" do
    expect {
      described_class.new.perform(today)
    }.not_to have_enqueued_job(AssessInterestChargeJob).with(positive_balance_credit.id, anything)
  end

  it "does not enqueue for non-credit accounts" do
    expect {
      described_class.new.perform(today)
    }.not_to have_enqueued_job(AssessInterestChargeJob).with(checking.id, anything)
  end

  it "defaults today to Date.current when no argument given" do
    travel_to(Date.new(2026, 5, 15)) do
      expect {
        described_class.new.perform
      }.to have_enqueued_job(AssessInterestChargeJob).with(due_credit.id, Date.current.to_s)
    end
  end
end
