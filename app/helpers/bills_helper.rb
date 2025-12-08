# frozen_string_literal: true

module BillsHelper
  def grouped_bills_by_type(bills)
    Bill.bill_types.keys.index_with do |type|
      bills.select { |bill| bill.bill_type == type }
    end
  end

  def calendar_weeks(reference_date)
    start_date = reference_date.beginning_of_month.beginning_of_week(:sunday)
    end_date = reference_date.end_of_month.end_of_week(:sunday)
    (start_date..end_date).to_a.each_slice(7).to_a
  end
end

