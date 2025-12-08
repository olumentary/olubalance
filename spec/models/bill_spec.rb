# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bill, type: :model do
  it "has a valid factory" do
    expect(build(:bill)).to be_valid
  end

  describe 'associations' do
    it { should belong_to(:account) }
    it { should belong_to(:user) }
  end

  describe 'enums' do
    it { should define_enum_for(:bill_type).with_values(income: 'income', expense: 'expense', debt_repayment: 'debt_repayment', payment_plan: 'payment_plan').with_prefix.backed_by_column_of_type(:string) }
    it { should define_enum_for(:category).with_values(income: 'income', utility: 'utility', family: 'family', auto: 'auto', food: 'food', housing: 'housing', misc: 'misc', internet: 'internet', health: 'health', insurance: 'insurance', phone: 'phone', credit_card: 'credit_card', taxes: 'taxes').with_prefix.backed_by_column_of_type(:string) }
    it { should define_enum_for(:frequency).with_values(monthly: 'monthly', bi_weekly: 'bi_weekly', quarterly: 'quarterly', annual: 'annual').backed_by_column_of_type(:string) }
  end

  describe 'validations' do
    it { should validate_presence_of(:description) }
    it { should validate_length_of(:description).is_at_most(150) }
    it { should validate_presence_of(:day_of_month) }
    it { should validate_numericality_of(:day_of_month).only_integer.is_greater_than_or_equal_to(1).is_less_than_or_equal_to(31) }
    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }
    it { should validate_length_of(:notes).is_at_most(2000) }
    it { should validate_presence_of(:account) }
    it { should validate_presence_of(:user) }
  end

  describe '#account_belongs_to_user' do
    let(:user) { create(:user, :confirmed) }
    let(:other_user) { create(:user, :confirmed) }
    let(:account) { create(:account, user: user) }
    let(:other_account) { create(:account, user: other_user) }

    it 'is valid when the account belongs to the user' do
      bill = build(:bill, user: user, account: account)
      expect(bill).to be_valid
    end

    it 'is invalid when the account belongs to another user' do
      bill = build(:bill, user: user, account: other_account)
      expect(bill).not_to be_valid
      expect(bill.errors[:account_id]).to include("must belong to your profile")
    end
  end

  describe '#calendar_date_for' do
    let(:bill) { build(:bill, day_of_month: 31) }
    let(:reference_date) { Date.new(2025, 2, 1) }

    it 'clamps to the last day of the month when needed' do
      expect(bill.calendar_date_for(reference_date).day).to eq(reference_date.end_of_month.day)
    end
  end
end

