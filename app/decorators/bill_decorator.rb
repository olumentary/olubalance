# frozen_string_literal: true

class BillDecorator < ApplicationDecorator
  decorates_finders
  delegate_all
  include Draper::LazyHelpers

  def bill_type_label
    bill_type.humanize.titleize
  end

  def category_label
    category&.name || '—'
  end

  def frequency_label
    frequency.humanize.titleize
  end

  def biweekly_mode_label
    return "Bi-Weekly" unless biweekly_mode

    biweekly_mode.humanize.titleize
  end

  def day_of_month_label
    day_of_month.ordinalize
  end

  def second_day_of_month_label
    second_day_of_month&.ordinalize
  end

  def amount_display
    number_to_currency(amount)
  end

  def notes_display
    notes.presence || "—"
  end

  def account_display
    account.name
  end

  def calendar_date_for(reference_date = Time.zone.today)
    object.calendar_date_for(reference_date)
  end

  def occurrences_for_month(reference_date = Time.zone.today)
    object.occurrences_for_month(reference_date)
  end

  def monthly_normalized_amount
    object.monthly_normalized_amount
  end

  def monthly_normalized_breakdown
    monthly_amount_display = number_to_currency(monthly_normalized_amount)
    base_amount_display = number_to_currency(amount)

    case frequency
    when "monthly"
      "Monthly: #{base_amount_display}"
    when "bi_weekly"
      if biweekly_mode == "two_days"
        days = [day_of_month_label, second_day_of_month_label].compact.join(" & ")
        occurrences = [day_of_month, second_day_of_month].compact.size
        "Bi-Weekly (#{days.presence || 'twice per month'}): #{base_amount_display} × #{occurrences} = #{monthly_amount_display}"
      else
        "Bi-Weekly (every other week): #{base_amount_display} × 26 / 12 = #{monthly_amount_display}"
      end
    when "quarterly"
      "Quarterly: #{base_amount_display} ÷ 3 = #{monthly_amount_display}"
    when "annual"
      "Annual: #{base_amount_display} ÷ 12 = #{monthly_amount_display}"
    else
      monthly_amount_display
    end
  end
end

