# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssessInterestChargeJob, type: :job do
  let(:user) { FactoryBot.create(:user) }
  let(:charge_date) { Date.new(2026, 5, 15) }
  let!(:account) do
    FactoryBot.create(:account, :credit,
                      user: user,
                      starting_balance: -500,
                      statement_day: 15,
                      interest_rate: 24.0)
  end

  it "creates a pending interest-charge transaction with the correct shape" do
    expect {
      described_class.new.perform(account.id, charge_date.to_s)
    }.to change { account.transactions.count }.by(1)

    txn = account.transactions.order(:created_at).last
    expect(txn.description).to eq("Interest Charge - May 2026")
    expect(txn.trx_date).to eq(charge_date)
    expect(txn.pending).to be true
    expect(txn.locked).to be false
    expect(txn.amount).to eq(BigDecimal("-10.00")) # debit => negative; 500 * 24% / 12 = 10
    expect(txn.category.name).to eq("Interest Charges")
  end

  it "stamps last_interest_charged_on" do
    described_class.new.perform(account.id, charge_date.to_s)
    expect(account.reload.last_interest_charged_on).to eq(charge_date)
  end

  it "is idempotent within the same calendar month" do
    described_class.new.perform(account.id, charge_date.to_s)
    expect {
      described_class.new.perform(account.id, charge_date.to_s)
    }.not_to change { account.transactions.count }
  end

  it "skips when the account is no longer eligible (positive balance)" do
    account.update_column(:current_balance, 0)
    expect {
      described_class.new.perform(account.id, charge_date.to_s)
    }.not_to change { account.transactions.count }
  end

  it "skips when the account has missing config" do
    account.update_column(:statement_day, nil)
    expect {
      described_class.new.perform(account.id, charge_date.to_s)
    }.not_to change { account.transactions.count }
  end

  it "creates a charge again the following month" do
    described_class.new.perform(account.id, charge_date.to_s)
    next_month = Date.new(2026, 6, 15)
    expect {
      described_class.new.perform(account.id, next_month.to_s)
    }.to change { account.transactions.count }.by(1)
  end
end
