# frozen_string_literal: true

class SearchController < ApplicationController
  include Pagy::Backend

  before_action :authenticate_user!
  before_action :load_user_accounts
  before_action :load_categories

  def index
    # Get base scope of transactions belonging to current user
    @transactions = Transaction.joins(:account).where(accounts: { user_id: current_user.id })

    # Apply fuzzy search if query is present
    if params[:query].present?
      @transactions = @transactions.fuzzy_search(params[:query])
    else
      @transactions = @transactions.order(trx_date: :desc, id: :desc)
    end

    # Apply filters
    apply_filters

    # Paginate results
    @pagy, @transactions = pagy(@transactions.includes(:account, :category))
    @transactions = @transactions.decorate

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def load_user_accounts
    @user_accounts = current_user.accounts.active.order(:name)
  end

  def load_categories
    @categories = Category.for_user(current_user).ordered
  end

  def apply_filters
    if params[:account_id].present?
      @transactions = @transactions.where(account_id: params[:account_id])
    end

    if params[:category_id].present?
      @transactions = @transactions.where(category_id: params[:category_id])
    end

    if params[:start_date].present?
      @transactions = @transactions.where("trx_date >= ?", params[:start_date])
    end

    if params[:end_date].present?
      @transactions = @transactions.where("trx_date <= ?", params[:end_date])
    end
  end
end

