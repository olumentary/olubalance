# frozen_string_literal: true

class ReportsController < ApplicationController
  before_action :authenticate_user!

  def index
    @accounts = current_user.accounts.active.order(:name)
    @categories = Category.for_user(current_user).ordered

    @start_date = parse_date(params[:start_date]) || Date.current.beginning_of_month
    @end_date = parse_date(params[:end_date]) || Date.current
    @selected_category_ids = Array(params[:category_ids]).reject(&:blank?)
    @selected_account_ids = Array(params[:account_ids]).reject(&:blank?)

    @report_data = Reporting::SpendingByCategory.new(
      user: current_user,
      start_date: @start_date,
      end_date: @end_date,
      category_ids: @selected_category_ids,
      account_ids: @selected_account_ids
    ).call
  end

  private

  def parse_date(date_string)
    return nil if date_string.blank?

    Date.parse(date_string)
  rescue ArgumentError
    nil
  end
end

