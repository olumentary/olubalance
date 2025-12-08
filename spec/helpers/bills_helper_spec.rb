# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BillsHelper, type: :helper do
  describe '#grouped_bills_by_type' do
    let(:income_bill) { build(:bill, bill_type: 'income').decorate }
    let(:expense_bill) { build(:bill, bill_type: 'expense').decorate }

    it 'groups by bill type and preserves keys for all enums' do
      grouped = helper.grouped_bills_by_type([income_bill, expense_bill])
      expect(grouped['income']).to include(income_bill)
      expect(grouped['expense']).to include(expense_bill)
      expect(grouped.keys).to include(*Bill.bill_types.keys)
    end
  end

  describe '#calendar_weeks' do
    it 'builds weeks covering the reference month' do
      reference_date = Date.new(2025, 3, 15)
      weeks = helper.calendar_weeks(reference_date)
      expect(weeks.first.first).to be_a(Date)
      expect(weeks.flatten.map(&:month)).to include(3)
      expect(weeks.flatten.size).to eq(weeks.size * 7)
    end
  end
end

