# frozen_string_literal: true

class TransactionDecorator < ApplicationDecorator
  decorates_finders
  decorates_association :transaction_balance
  delegate_all
  include Draper::LazyHelpers

  def debit
    amount.negative? ? number_to_currency(amount.abs) : "&nbsp;".html_safe
  end

  def credit
    amount.positive? ? number_to_currency(amount) : "&nbsp;".html_safe
  end

  def amount_decorated
    amount.negative? ? number_to_currency(amount.abs) : number_to_currency(amount)
  end

  def amount_form
    amount.present? ? number_with_precision(amount.abs, precision: 2) : nil
  end

  def amount_color
    amount.negative? ? "has-text-danger" : "has-text-success"
  end

  def trx_type_value_form
    if object.new_record?
      "debit"
    else
      amount.present? ? (amount.negative? ? "debit" : "credit") : nil
    end
  end

  def memo_decorated
    memo? ? memo : "- None -"
  end

  def filename_size
    attachment.attached? ? attachment.filename.to_s + " (" + number_to_human_size(attachment.byte_size).to_s + ")" : nil
  end

  def filename_form
    attachment.attached? ? filename_size : "- No receipt -"
  end

  def add_receipt_button_label
    attachment.attached? ? "Change receipt..." : "Add receipt..."
  end

  def running_balance_display
    number_to_currency(running_balance)
  end

  def trx_date_decorated
    transaction.pending ? "PENDING" : trx_date_display
  end

  def trx_date_display
    trx_date.in_time_zone(User.new.decorate.h.controller.current_user.timezone).strftime("%m/%d/%Y")
  end

  def trx_date_formatted
    # trx_date.in_time_zone(current_user.timezone).strftime('%m/%d/%Y')
    trx_date.in_time_zone(User.new.decorate.h.controller.current_user.timezone).strftime("%Y-%m-%d")
  end

  def trx_date_form_value
    # trx_date.present? ? trx_date_formatted : Time.current.strftime('%m/%d/%Y')
    trx_date.present? ? trx_date_formatted : Time.current.strftime("%Y-%m-%d")
  end

  def created_at_decorated
    created_at.in_time_zone(User.new.decorate.h.controller.current_user.timezone).strftime("%b %d, %Y @ %I:%M %p %Z")
  end

  def name_too_long
    description.length > 35
  end

  def trx_desc_display
    name_too_long ? description[0..35] + "..." : description
  end
end
