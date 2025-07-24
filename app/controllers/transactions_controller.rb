# frozen_string_literal: true

class TransactionsController < ApplicationController
  include Pagy::Backend
  include PerformanceMonitoring

  before_action :authenticate_user!
  before_action :find_account
  before_action :find_transaction, only: %i[edit update show destroy update_date update_attachment]
  before_action :transfer_accounts, only: %i[index mark_reviewed mark_pending]
  before_action :check_account_change, only: [ :index ]
  before_action :load_user_accounts, only: [ :new, :create, :edit, :update, :index ]

  # Index action to render all transactions
  def index
    session["filters"] ||= {}
    session["filters"].merge!(filter_params)

    @transactions = @account.transactions.with_attached_attachment.includes(:transaction_balance)
                            .then { search_by_description _1 }
                            .then { apply_pending_order _1 }
                            .then { apply_order _1 }
                            .then { apply_id_order _1 }
                            .limit(20) # Add explicit limit to prevent loading too many records

    @pagy, @transactions = pagy(@transactions)
    @transactions = @transactions.decorate

    @stashes = @account.stashes.order(id: :asc).decorate
    @stashed = @account.stashes.sum(:balance)

    respond_to do |format|
      format.html # index.html.erb
      format.xml { render xml: @transactions }
    end
  end

  # New action for creating transaction
  def new
    @transaction = @account.transactions.build.decorate

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render xml: @transaction }
    end
  end

  # Create action saves the trasaction into database
  def create
    @transaction = @account.transactions.build(transaction_params).decorate

    if @transaction.save
      redirect_to account_transactions_path, notice: "Transaction was successfully created."
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  # Edit action retrieves the transaction and renders the edit page
  def edit
  end

  # Update action updates the transaction with the new information
  def update
    # For quick receipt transactions, always default to debit unless explicitly set otherwise
    if @transaction.quick_receipt? && !params.dig(:transaction, :trx_type)
      @transaction.trx_type = "debit"
    else
      # Preserve trx_type if not present in params
      @transaction.trx_type = params.dig(:transaction, :trx_type) || (@transaction.amount&.negative? ? "debit" : "credit")
    end

    if @transaction.update(transaction_params)
      respond_to do |format|
        format.html { redirect_to account_transactions_path, notice: "Transaction was successfully updated." }
        format.turbo_stream { redirect_to account_transactions_path, notice: "Transaction was successfully updated." }
        format.json {
          response_data = {
            id: @transaction.id,
            success: true
          }

          # Add the updated field to the response
          if params[:transaction]&.key?(:description)
            response_data[:description] = @transaction.description
          elsif params[:transaction]&.key?(:amount)
            response_data[:amount] = @transaction.amount
          elsif params[:transaction]&.key?(:trx_type)
            response_data[:trx_type] = @transaction.trx_type
          elsif params[:date]
            response_data[:trx_date] = @transaction.trx_date
          end

          render json: response_data, content_type: "application/json"
        }
      end
    else
      respond_to do |format|
        format.html { render action: "edit", status: :unprocessable_entity }
        format.turbo_stream { render action: "edit", status: :unprocessable_entity }
        format.json {
          render json: {
            success: false,
            errors: @transaction.errors.full_messages
          }, status: :unprocessable_entity, content_type: "application/json"
        }
      end
    end
  end

  # The show action renders the individual transaction after retrieving the the id
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.xml { render xml: @transaction }
    end
  end

  # The destroy action removes the transaction permanently from the database
  def destroy
    @transaction.destroy

    respond_to do |format|
      format.html { redirect_to(account_transactions_url) }
      format.xml { head :ok }
    end
  end

  def mark_reviewed
    @transaction = Transaction.find(params[:id])

    if @transaction.update(pending: false)
      # Reload the transaction to ensure we have the latest data
      @transaction.reload
      @transaction = @transaction.decorate

      # Force a complete reload of transactions for the updated table
      @account.reload
      # Force reload of the transactions association to ensure pending_balance calculation is fresh
      @account.transactions.reload
      @transactions = @account.transactions.with_attached_attachment.includes(:transaction_balance)
                              .then { search_by_description _1 }
                              .then { apply_pending_order _1 }
                              .then { apply_order _1 }
                              .then { apply_id_order _1 }

      @pagy, @transactions = pagy(@transactions)
      @transactions = @transactions.decorate

      # Debug: Log the pending count
      pending_count = @transactions.select(&:pending?).count
      Rails.logger.info "Mark reviewed - Pending count: #{pending_count}, Total transactions: #{@transactions.count}"

      # Set required variables for partials
      @stashes = @account.stashes.order(id: :asc).decorate
      @stashed = @account.stashes.sum(:balance)

      respond_to do |format|
        format.turbo_stream
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash_messages", partial: "shared/error_messages", locals: { errors: @transaction.errors.full_messages }) }
        format.json { render json: { success: false, errors: @transaction.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def mark_pending
    @transaction = Transaction.find(params[:id])

    if @transaction.update(pending: true)
      # Reload the transaction to ensure we have the latest data
      @transaction.reload
      @transaction = @transaction.decorate

      # Force a complete reload of transactions for the updated table
      @account.reload
      # Force reload of the transactions association to ensure pending_balance calculation is fresh
      @account.transactions.reload
      @transactions = @account.transactions.with_attached_attachment.includes(:transaction_balance)
                              .then { search_by_description _1 }
                              .then { apply_pending_order _1 }
                              .then { apply_order _1 }
                              .then { apply_id_order _1 }

      @pagy, @transactions = pagy(@transactions)
      @transactions = @transactions.decorate

      # Debug: Log the pending count
      pending_count = @transactions.select(&:pending?).count
      Rails.logger.info "Mark pending - Pending count: #{pending_count}, Total transactions: #{@transactions.count}"

      # Set required variables for partials
      @stashes = @account.stashes.order(id: :asc).decorate
      @stashed = @account.stashes.sum(:balance)

      respond_to do |format|
        format.turbo_stream
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash_messages", partial: "shared/error_messages", locals: { errors: @transaction.errors.full_messages }) }
        format.json { render json: { success: false, errors: @transaction.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # GET /transactions/descriptions
  def descriptions
    query = params[:query].to_s.strip
    descriptions = @account.transactions
                         .where("description ILIKE ?", "%#{query}%")
                         .distinct
                         .pluck(:description)
                         .first(10)

    render json: descriptions
  end

  def update_date
    if @transaction.update_date_only(params[:date])
      render json: { success: true, trx_date: @transaction.trx_date }
    else
      render json: { success: false, errors: @transaction.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_attachment
    if @transaction.update(attachment: params[:transaction][:attachment])
      render json: {
        success: true,
        filename: @transaction.attachment.filename.to_s,
        has_attachment: @transaction.attachment.attached?
      }
    else
      render json: {
        success: false,
        errors: @transaction.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Error in update_attachment: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: {
      success: false,
      errors: [ "An error occurred while updating the attachment: #{e.message}" ]
    }, status: :internal_server_error
  end

  private

  def load_user_accounts
    @user_accounts = current_user.accounts.where(active: true).order(:name).decorate
  end

  def filter_params
    params.permit(:description, :account_id)
  end

  def transaction_params
    if request.format.json?
      # For JSON requests, handle different field types
      if params[:transaction]&.key?(:description) && params[:transaction]&.key?(:amount) && params[:transaction]&.key?(:trx_type) && params[:transaction]&.key?(:trx_date)
        # Handle full form submission (like from Quick Receipt review modal)
        { 
          description: params[:transaction][:description],
          amount: params[:transaction][:amount],
          trx_type: params[:transaction][:trx_type],
          trx_date: params[:transaction][:trx_date],
          memo: params[:transaction][:memo],
          account_id: params[:transaction][:account_id]
        }
      elsif params[:transaction]&.key?(:description)
        { description: params[:transaction][:description] }
      elsif params[:transaction]&.key?(:amount) && params[:transaction]&.key?(:trx_type)
        # Handle both amount and trx_type together for type toggle
        { amount: params[:transaction][:amount], trx_type: params[:transaction][:trx_type] }
      elsif params[:transaction]&.key?(:amount)
        { amount: params[:transaction][:amount] }
      elsif params[:transaction]&.key?(:trx_type)
        { trx_type: params[:transaction][:trx_type] }
      elsif params[:date]
        { trx_date: params[:date] }
      else
        {}
      end
    else
      params.require(:transaction) \
            .permit(:trx_date, :description, :amount, :trx_type, :memo, :attachment, :page, :locked, :transfer, :account_id, :pending)
    end
  end

  def search_by_description(scope)
    session["filters"]["description"].present? ? scope.where("UPPER(description) like UPPER(?)", "%#{session['filters']['description']}%") : scope
  end

  def apply_pending_order(scope)
    scope.order(pending: :desc)
  end

  def apply_order(scope)
    # scope.order(session["filters"].slice("column", "direction").values.join(" "))
    scope.order(trx_date: :desc)
  end

  def apply_id_order(scope)
    scope.order(id: :desc)
  end

  def check_account_change
    # If there is no account ID stored in the session, set it to the current account
    if session[:current_account_id].nil? || session[:current_account_id] != @account.id
      session[:current_account_id] = @account.id
      session["filters"] = {} # Clear filters when the account is set or changed
    end
  end

  def find_account
    @account = current_user.accounts.find(params[:account_id]).decorate
    unless @account.active?
      redirect_to accounts_inactive_path, notice: "Account is inactive"
    end
  end

  def transfer_accounts
    account_id = @account.id
    @transfer_accounts = Rails.cache.fetch("user_#{current_user.id}_transfer_accounts_#{account_id}", expires_in: 10.minutes) do
      current_user.accounts.where("active = ?", "true").where("account_type != ?", "credit").where(
        "id != ?", account_id
      ).decorate
    end
  end

  def find_transaction
    @transaction = @account.transactions.find(params[:id]).decorate
  end
end
