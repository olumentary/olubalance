# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BillDecorator do
  let(:bill) { build(:bill, day_of_month: 10, amount: 150.25).decorate }

  describe '#amount_display' do
    it 'formats amount as currency' do
      expect(bill.amount_display).to eq(ActionController::Base.helpers.number_to_currency(150.25))
    end
  end

  describe '#day_of_month_label' do
    it 'shows ordinalized day' do
      expect(bill.day_of_month_label).to eq('10th')
    end
  end

  describe '#calendar_date_for' do
    let(:reference_date) { Date.new(2025, 5, 1) }

    it 'returns a date in the reference month' do
      expect(bill.calendar_date_for(reference_date).month).to eq(5)
      expect(bill.calendar_date_for(reference_date).day).to eq(10)
    end
  end

  describe '#monthly_normalized_breakdown' do
    it 'builds a readable breakdown for monthly bills' do
      expect(bill.monthly_normalized_breakdown).to include('Monthly')
      expect(bill.monthly_normalized_breakdown).to include(ActionController::Base.helpers.number_to_currency(150.25))
    end

    it 'shows every other week math for bi-weekly bills' do
      biweekly_bill = build(:bill, :bi_weekly, amount: 100).decorate
      expect(biweekly_bill.monthly_normalized_breakdown).to include('26 / 12')
    end

    it 'shows two-day math for bi-weekly two day mode' do
      two_day_bill = build(:bill, :bi_weekly_two_days, amount: 50, day_of_month: 5, second_day_of_month: 20).decorate
      expect(two_day_bill.monthly_normalized_breakdown).to include('× 2')
    end
  end
end

