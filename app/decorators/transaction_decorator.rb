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
    return "Pending" if amount.nil?
    formatted_amount = sprintf("%.2f", amount.abs)
    amount.negative? ? number_to_currency(formatted_amount, precision: 2) : number_to_currency(formatted_amount, precision: 2)
  end

  def amount_form
    amount.present? ? number_with_precision(amount.abs, precision: 2) : nil
  end

  def amount_color
    return "has-text-grey" if amount.nil?
    amount.negative? ? "has-text-danger" : "has-text-success"
  end

  def reviewed_color
    transaction.pending ? "has-background-white" : "has-background-text-90"
  end

  def reviewed_weight
    transaction.pending ? "has-text-weight-bold" : "has-text-weight-normal"
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
    if attachments.attached?
      if attachments.count == 1
        attachment = attachments.first
        attachment.filename.to_s + " (" + number_to_human_size(attachment.byte_size).to_s + ")"
      else
        "#{attachments.count} files"
      end
    else
      nil
    end
  end

  def filename_form
    attachments.attached? ? filename_size : "- No receipts -"
  end

  def add_receipt_button_label
    attachments.attached? ? "Add more receipts..." : "Add receipts..."
  end

  def attachment_upload_help_text
    attachments.attached? ? "Select additional receipts to add to this transaction" : "Select receipts to attach to this transaction"
  end

  def button_label
    new_record? ? "Create Transaction" : "Update Transaction"
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

  def trx_desc_display
    return "Pending Receipt" if description.nil?
    name_too_long ? "#{description[0..50]}..." : description
  end

  def trx_desc_display_mobile
    return "Pending Receipt" if description.nil?
    name_too_long_mobile ? "#{description[0..20]}..." : description
  end

  def name_too_long
    return false if description.nil?
    description.length > 50
  end

  def name_too_long_mobile
    return false if description.nil?
    description.length > 20
  end
end
