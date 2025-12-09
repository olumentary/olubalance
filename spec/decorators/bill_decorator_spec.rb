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
end

