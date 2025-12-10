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

  describe 'bi-weekly validation rules' do
    it 'requires second_day_of_month for two day mode' do
      bill = build(:bill, frequency: 'bi_weekly', biweekly_mode: 'two_days', second_day_of_month: nil)
      expect(bill).not_to be_valid
      expect(bill.errors[:second_day_of_month]).to be_present
    end

    it 'requires anchor fields for every other week mode' do
      bill = build(:bill, frequency: 'bi_weekly', biweekly_mode: 'every_other_week', biweekly_anchor_date: nil, biweekly_anchor_weekday: nil)
      expect(bill).not_to be_valid
      expect(bill.errors[:biweekly_anchor_date]).to be_present
      expect(bill.errors[:biweekly_anchor_weekday]).to be_present
    end
  end

  describe 'quarterly/annual validation rules' do
    it 'requires next_occurrence_month for quarterly' do
      bill = build(:bill, frequency: 'quarterly', next_occurrence_month: nil)
      expect(bill).not_to be_valid
      expect(bill.errors[:next_occurrence_month]).to be_present
    end
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

  describe '#occurrences_for_month' do
    let(:reference_date) { Date.new(2025, 1, 1) }

    it 'returns both days for bi-weekly two day mode' do
      bill = build(:bill, :bi_weekly_two_days, day_of_month: 5, second_day_of_month: 20)
      expect(bill.occurrences_for_month(reference_date).map(&:day)).to contain_exactly(5, 20)
    end

    it 'returns clamped dates when needed' do
      bill = build(:bill, :bi_weekly_two_days, day_of_month: 30, second_day_of_month: 31)
      dates = bill.occurrences_for_month(Date.new(2025, 2, 1))
      expect(dates.map(&:day)).to eq([28, 28])
    end

    it 'returns every other week occurrences for the month' do
      anchor_date = Date.new(2025, 1, 3) # Friday
      bill = build(:bill, frequency: 'bi_weekly', biweekly_mode: 'every_other_week', biweekly_anchor_date: anchor_date, biweekly_anchor_weekday: anchor_date.wday, day_of_month: 1)
      dates = bill.occurrences_for_month(reference_date)
      expect(dates).to include(anchor_date, anchor_date + 14.days)
    end

    it 'returns quarterly occurrence when month matches cycle' do
      bill = build(:bill, :quarterly, next_occurrence_month: 1, day_of_month: 10)
      expect(bill.occurrences_for_month(reference_date).map(&:day)).to eq([10])
      expect(bill.occurrences_for_month(Date.new(2025, 2, 1))).to be_empty
    end
  end

  describe '#monthly_normalized_amount' do
    it 'uses 26/12 for every other week' do
      bill = build(:bill, :bi_weekly, amount: 1200)
      expect(bill.monthly_normalized_amount).to eq(BigDecimal('1200') * BigDecimal('26') / BigDecimal('12'))
    end

    it 'uses per-occurrence count for two day mode' do
      bill = build(:bill, :bi_weekly_two_days, amount: 100, day_of_month: 5, second_day_of_month: 20)
      expect(bill.monthly_normalized_amount).to eq(200)
    end

    it 'divides quarterly amounts by 3' do
      bill = build(:bill, :quarterly, amount: 300)
      expect(bill.monthly_normalized_amount).to eq(100)
    end

    it 'divides annual amounts by 12' do
      bill = build(:bill, :annual, amount: 1200)
      expect(bill.monthly_normalized_amount).to eq(100)
    end
  end
end

