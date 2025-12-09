# frozen_string_literal: true

module BillsHelper
  def grouped_bills_by_type(bills)
    Bill.bill_types.keys.index_with do |type|
      bills.select { |bill| bill.bill_type == type }
    end
  end

  def calendar_weeks(reference_date)
    base_date = reference_date.to_date
    start_date = base_date.beginning_of_month.beginning_of_week(:sunday)
    end_date = base_date.end_of_month.end_of_week(:sunday)
    (start_date..end_date).to_a.each_slice(7).to_a
  end

  def summary_bill_payload(bills)
    bills.map do |bill|
      {
        description: bill.description,
        detail: summary_detail_for(bill),
        monthly_amount: bill.monthly_normalized_amount.to_d
      }
    end
  end

  private

  def summary_detail_for(bill)
    base = bill.amount_display
    monthly = number_to_currency(bill.monthly_normalized_amount)

    case bill.frequency
    when "monthly"
      "(#{bill.frequency_label}) - #{base}"
    when "bi_weekly"
      if bill.biweekly_mode == "two_days"
        count = [bill.day_of_month, bill.second_day_of_month].compact.size
        "(#{bill.frequency_label}) - #{base} × #{count} = #{monthly}"
      else
        "(#{bill.frequency_label}) - #{base} × 26 / 12 = #{monthly}"
      end
    when "quarterly"
      "(#{bill.frequency_label}) - #{base} ÷ 3 = #{monthly}"
    when "annual"
      "(#{bill.frequency_label}) - #{base} ÷ 12 = #{monthly}"
    else
      "(#{bill.frequency_label}) - #{monthly}"
    end
  end
end
