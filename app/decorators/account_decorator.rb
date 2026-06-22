# frozen_string_literal: true

class AccountDecorator < ApplicationDecorator
  decorates_finders
  decorates_association :user
  decorates_association :transaction
  delegate_all
  include Draper::LazyHelpers

  # Display the account name with last four if present
  def account_name
    last_four.present? ? name + " ( ... " + last_four.to_s + ")" : name
  end

  # Check if the account name is longer than the display limit for account cards
  def name_too_long
    name.length > Account::DISPLAY_NAME_LIMIT
  end

  # Truncate the account name on Accound cards if too long
  def account_card_title
    name_too_long ? name[0..Account::DISPLAY_NAME_LIMIT] + "..." : name
  end

  # Display the last four digits of the account
  def last_four_display
    last_four.present? ? "xx" + last_four.to_s : nil
  end

  # Display the current account balance in currency format
  def current_balance_display
    number_to_currency(current_balance)
  end

  # Display the pending account balance in currency format
  def pending_balance_display
    number_to_currency(pending_balance)
  end

  # Display the non-pending account balance in currency format
  def non_pending_balance_display
    number_to_currency(non_pending_balance)
  end

  # Display the account name with current balance
  def account_name_balance
    name + " (" + current_balance_display + ")"
  end

  # Display the descriptive last updated at date for the account
  def updated_at_display
    updated_at.in_time_zone(User.new.decorate.h.controller.current_user.timezone).strftime("%b %d, %Y @ %I:%M %p %Z")
  end

  # Simple check if the account balance is negative
  def balance_negative?
    current_balance.negative?
  end

  # Set the balance color to red if the amount is negative
  def balance_color
    return "has-text-grey-dark" if account.credit?

    balance_negative? ? "has-text-danger" : "has-text-grey-dark"
  end

  def noaccounts_partial
    render partial: "noaccounts", locals: { description: NO_ACCOUNT_DESC } if @accounts.empty?
  end

  def account_icon
    case account_type
    when "credit"
      "fa-credit-card"
    when "checking"
      "fa-money-check"
    else
      "fa-piggy-bank"
    end
  end

  def last_transaction_on_display
    return "Never" if last_transaction_on.blank?

    last_transaction_on.in_time_zone(current_timezone).strftime("%b %d, %Y")
  end

  def days_since_last_transaction
    return nil if last_transaction_on.blank?

    (Date.current - last_transaction_on).to_i
  end

  private

  # Match the timezone resolution used by `updated_at_display` so display
  # formats remain consistent across the dashboard. The Draper helper chain
  # exposes the controller; ActionMailer/console contexts lack one, so we
  # gracefully fall back to UTC.
  def current_timezone
    h.controller.current_user.timezone
  rescue StandardError
    "UTC"
  end
end
