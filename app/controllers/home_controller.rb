# frozen_string_literal: true

class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    # Load account data for the desktop view
    @accounts = current_user.accounts.where(active: true).order("created_at ASC")

    @accounts_checking = @accounts.where(account_type: :checking)
    @accounts_savings_cash = @accounts.where(account_type: :savings).or(@accounts.where(account_type: :cash))
    @accounts_credit = @accounts.where(account_type: :credit)

    @checking_total = @accounts_checking.sum(:current_balance)
    @savings_cash_total = @accounts_savings_cash.sum(:current_balance)

    @credit_total = @accounts_credit.sum(:current_balance)
    @credit_limit_total = @accounts_credit.sum(:credit_limit)
    @credit_utilization_total = @credit_limit_total > 0 ? ((@credit_total.abs / @credit_limit_total) * 100).round(2) : 0

    @accounts_checking = @accounts_checking.decorate
    @accounts_savings_cash = @accounts_savings_cash.decorate
    @accounts_credit = @accounts_credit.decorate
    @accounts = @accounts.decorate
  end
end