# frozen_string_literal: true

class BillsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_accounts
  before_action :ensure_accounts_present, only: %i[new create]
  before_action :set_bill, only: %i[edit update destroy]

  def index
    @view_mode = params[:view] == "calendar" ? "calendar" : "list"
    @reference_date = resolve_reference_month
    @prev_month = (@reference_date - 1.month).strftime("%Y-%m")
    @next_month = (@reference_date + 1.month).strftime("%Y-%m")
    @bills = current_user.bills.includes(:account).ordered_for_list.decorate
    @bills_by_date = @bills.group_by { |bill| bill.calendar_date_for(@reference_date) }
    @bill_totals = monthly_totals(@bills)
    @bill_remaining = @bill_totals[:income] - @bill_totals.values_at(:expense, :debt_repayment, :payment_plan).sum
  end

  def new
    @bill = current_user.bills.build(default_bill_attributes).decorate
  end

  def create
    @bill = current_user.bills.build(bill_params).decorate

    if @bill.save
      redirect_to bills_path(view: params[:view].presence), notice: "Bill was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @bill.update(bill_params)
      redirect_to bills_path(view: params[:view].presence), notice: "Bill was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @bill.destroy
    redirect_to bills_path(view: params[:view].presence), notice: "Bill was deleted."
  end

  private

  def load_accounts
    @accounts = current_user.accounts.where(active: true).order(:name)
  end

  def ensure_accounts_present
    return if @accounts.any?

    redirect_to accounts_path, alert: "Add an account before creating bills."
  end

  def set_bill
    @bill = current_user.bills.includes(:account).find(params[:id]).decorate
  end

  def bill_params
    params.require(:bill)
          .permit(:bill_type, :category, :description, :frequency, :day_of_month, :amount, :notes, :account_id)
          .merge(user_id: current_user.id)
  end

  def default_bill_attributes
    default_account = @accounts.find_by(id: current_user.default_account_id) || @accounts.first

    {
      account: default_account,
      bill_type: nil,
      category: nil,
      frequency: Bill.frequencies.keys.first
    }
  end

  def resolve_reference_month
    return Time.zone.today.beginning_of_month if params[:month].blank?

    Date.strptime(params[:month], "%Y-%m").in_time_zone.beginning_of_month
  rescue ArgumentError
    Time.zone.today.beginning_of_month
  end

  def monthly_totals(bills)
    totals = {
      income: 0.to_d,
      expense: 0.to_d,
      debt_repayment: 0.to_d,
      payment_plan: 0.to_d
    }

    bills.each do |bill|
      monthly_amount = monthlyized_amount(bill)
      key = bill.bill_type.to_sym
      totals[key] += monthly_amount if totals.key?(key)
    end

    totals
  end

  def monthlyized_amount(bill)
    amount = bill.amount.to_d

    case bill.frequency
    when "monthly"
      amount
    when "bi_weekly"
      amount * BigDecimal("26") / BigDecimal("12")
    when "quarterly"
      amount / BigDecimal("3")
    when "annual"
      amount / BigDecimal("12")
    else
      amount
    end
  end
end

