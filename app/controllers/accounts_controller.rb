# frozen_string_literal: true

class AccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account, only: %i[show edit update destroy activate deactivate]

  # GET /accounts
  # GET /accounts.json
  def index
    @accounts = current_user.accounts.where(active: true).order("created_at ASC")

    @accounts_checking = @accounts.where(account_type: :checking)
    @accounts_savings_cash = @accounts.where(account_type: :savings).or(@accounts.where(account_type: :cash))
    @accounts_credit = @accounts.where(account_type: :credit)

    @checking_total = @accounts_checking.sum(:current_balance)
    @savings_cash_total = @accounts_savings_cash.sum(:current_balance)

    @credit_total = @accounts_credit.sum(:current_balance)
    @credit_limit_total = @accounts_credit.sum(:credit_limit)
    @credit_utilization_total = ((@credit_total.abs / @credit_limit_total) * 100).round(2)

    @accounts_checking = @accounts_checking.decorate
    @accounts_savings_cash = @accounts_savings_cash.decorate
    @accounts_credit = @accounts_credit.decorate
    @accounts = @accounts.decorate

    @quick_receipt_count = Transaction.quick_receipts
                                      .joins(:account)
                                      .where(accounts: { user_id: current_user.id, active: true })
                                      .count
  end

  def inactive
    @inactiveaccounts = current_user.accounts.where(active: false).order("created_at ASC")
    @inactiveaccounts = @inactiveaccounts.decorate
  end

  # GET /accounts/1
  # GET /accounts/1.json
  def show
  end

  # GET /accounts/new
  def new
    @account = current_user.accounts.build.decorate
  end

  # GET /accounts/1/edit
  def edit
  end

  # POST /accounts
  # POST /accounts.json
  def create
    @account = current_user.accounts.build(account_params).decorate

    if @account.save
      redirect_to accounts_path, notice: "Account was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /accounts/1
  # PATCH/PUT /accounts/1.json
  def update
    if @account.update(account_params)
      redirect_to accounts_path, notice: "Account was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /accounts/1
  # DELETE /accounts/1.json
  def destroy
    @account.destroy
    redirect_to accounts_url, notice: "Account was successfully deleted."
  end

  # Sets account active field to false
  def deactivate
    @account.active = false

    if @account.save
      redirect_to accounts_path, notice: "Account was deactivated."
    else
      render :show
    end
  end

  # Sets account active field to true
  def activate
    @account.active = true

    if @account.save
      redirect_to accounts_path, notice: "Account was activated."
    else
      render :show
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_account
    @account = current_user.accounts.find(params[:id]).decorate
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def account_params
    params.require(:account).permit(:name, :starting_balance, :current_balance, :last_four, :active, :account_type,
                                    :interest_rate, :credit_limit, :user_id)
  end
end
