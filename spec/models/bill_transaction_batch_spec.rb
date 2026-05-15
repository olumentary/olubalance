# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillTransactionBatch, type: :model do
  it "has a valid factory" do
    expect(build(:bill_transaction_batch)).to be_valid
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:transactions).dependent(:nullify) }
  end

  describe "reference assignment" do
    it "auto-assigns a UUID reference on validation" do
      batch = build(:bill_transaction_batch, period_month: Date.new(2026, 4, 1))
      batch.valid?
      expect(batch.reference).to match(/\A[0-9a-f-]{36}\z/)
    end

    it "validates uniqueness of reference" do
      first = create(:bill_transaction_batch)
      duplicate = build(:bill_transaction_batch, reference: first.reference, period_month: Date.new(2026, 4, 1))
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:reference]).to include("has already been taken")
    end
  end

  describe "period or range presence" do
    it "is valid with period_month only" do
      batch = build(:bill_transaction_batch, period_month: Date.new(2026, 4, 1))
      expect(batch).to be_valid
    end

    it "is valid with a complete date range" do
      batch = build(:bill_transaction_batch, period_month: nil,
                                             range_start_date: Date.new(2026, 4, 1),
                                             range_end_date: Date.new(2026, 4, 30))
      expect(batch).to be_valid
    end

    it "is invalid with neither" do
      batch = build(:bill_transaction_batch, period_month: nil)
      expect(batch).not_to be_valid
      expect(batch.errors[:base]).to include("Specify either period_month or a date range")
    end

    it "is invalid when range_end_date precedes range_start_date" do
      batch = build(:bill_transaction_batch, period_month: nil,
                                             range_start_date: Date.new(2026, 5, 1),
                                             range_end_date: Date.new(2026, 4, 30))
      expect(batch).not_to be_valid
      expect(batch.errors[:range_end_date]).to include("must be on or after the start date")
    end
  end

  describe "#month_label" do
    it "renders 'Month YYYY' when period_month is set" do
      batch = build(:bill_transaction_batch, period_month: Date.new(2026, 4, 1))
      expect(batch.month_label).to eq("April 2026")
    end

    it "renders an abbreviated date range when range_*_date are set" do
      batch = build(:bill_transaction_batch, period_month: nil,
                                             range_start_date: Date.new(2026, 4, 1),
                                             range_end_date: Date.new(2026, 4, 30))
      expect(batch.month_label).to include("Apr 1, 2026 - Apr 30, 2026")
    end

    it "falls back to 'Custom range' when neither is set" do
      batch = build(:bill_transaction_batch, period_month: nil)
      expect(batch.month_label).to eq("Custom range")
    end
  end

  describe ".ordered" do
    it "returns batches in created_at DESC order" do
      older = create(:bill_transaction_batch, created_at: 2.days.ago)
      newer = create(:bill_transaction_batch, created_at: 1.day.ago)
      expect(BillTransactionBatch.ordered.to_a).to eq([ newer, older ])
    end
  end
end
