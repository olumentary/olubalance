# frozen_string_literal: true

class BillDecorator < ApplicationDecorator
  decorates_finders
  delegate_all
  include Draper::LazyHelpers

  def bill_type_label
    bill_type.humanize.titleize
  end

  def category_label
    category.humanize.titleize
  end

  def frequency_label
    frequency.humanize.titleize
  end

  def day_of_month_label
    day_of_month.ordinalize
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
end

