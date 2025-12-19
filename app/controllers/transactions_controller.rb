# frozen_string_literal: true

class TransactionsController < ApplicationController
  include Pagy::Backend

  before_action :authenticate_user!
  before_action :find_account
  before_action :find_transaction, only: %i[edit update show destroy update_date update_attachment delete_attachment]
  before_action :transfer_accounts, only: %i[index mark_reviewed mark_pending]
  before_action :check_account_change, only: [ :index ]
  before_action :load_user_accounts, only: [ :new, :create, :edit, :update, :index ]
  before_action :load_categories, only: %i[new create edit update index]

  # Index action to render all transactions
  def index
    session["filters"] ||= {}
    session["filters"].merge!(filter_params)

    # Build filtered transaction scope (before pagination)
    filtered_transactions = @account.transactions
                                    .with_attached_attachments
                                    .includes(:transaction_balance, :category)
                                    .then { search_by_description _1 }
                                    .then { apply_pending_order _1 }
                                    .then { apply_order _1 }
                                    .then { apply_id_order _1 }

    # Calculate pending_balance from filtered transactions (before pagination)
    # This ensures the balance matches what's visible in the filtered set
    @pending_balance = filtered_transactions.where(pending: true).sum(:amount)

    # Paginate the filtered transactions
    @pagy, @transactions = pagy(filtered_transactions)
    @transactions = @transactions.decorate

    # Pre-calculate transaction groupings to avoid repeated collection operations
    group_transactions_for_display

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
    apply_category_suggestion(@transaction)

    if @transaction.save
      redirect_to account_transactions_path, notice: "Transaction was successfully created."
    else
      respond_to do |format|
        @category_suggestion ||= category_suggester.suggest(@transaction.description)
        format.html { render :new, status: :unprocessable_content }
        format.turbo_stream { render :new, status: :unprocessable_content }
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

    # Handle attachments separately to append new ones to existing ones
    new_attachments = params[:transaction][:attachments] if params[:transaction]&.key?(:attachments)
    
    # Remove attachments from params to prevent replacement
    transaction_params_without_attachments = transaction_params.except(:attachments)

    # Check if account is being changed
    account_changed = params[:transaction]&.key?(:account_id) && 
                     params[:transaction][:account_id].to_i != @transaction.account_id

    @transaction.assign_attributes(transaction_params_without_attachments)
    apply_category_suggestion(@transaction)

    if @transaction.save
      # Attach new files if any were provided
      if new_attachments.present?
        files = Array(new_attachments)
        files.each do |file|
          @transaction.attachments.attach(file)
        end
      end

      # Set appropriate redirect based on account change
      if account_changed
        new_account = Account.find(params[:transaction][:account_id])
        redirect_path = account_transactions_path(new_account)
        notice_message = "Transaction was successfully moved to #{new_account.name}."
      else
        redirect_path = account_transactions_path(@transaction.account)
        notice_message = "Transaction was successfully updated."
      end

      respond_to do |format|
        format.html { redirect_to redirect_path, notice: notice_message }
        format.turbo_stream { redirect_to redirect_path, notice: notice_message }
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
          elsif params[:transaction]&.key?(:account_id)
            response_data[:account_id] = @transaction.account_id
            response_data[:account_name] = @transaction.account.name
          elsif params[:date]
            response_data[:trx_date] = @transaction.trx_date
          end

          render json: response_data, content_type: "application/json"
        }
      end
    else
      respond_to do |format|
        @category_suggestion ||= category_suggester.suggest(@transaction.description)
        format.html { render action: "edit", status: :unprocessable_content }
        format.turbo_stream { render action: "edit", status: :unprocessable_content }
        format.json {
          render json: {
            success: false,
            errors: @transaction.errors.full_messages
          }, status: :unprocessable_content, content_type: "application/json"
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
      
      # Build filtered transaction scope (before pagination)
      filtered_transactions = @account.transactions
                                      .with_attached_attachments
                                      .includes(:transaction_balance, :category)
                                      .then { search_by_description _1 }
                                      .then { apply_pending_order _1 }
                                      .then { apply_order _1 }
                                      .then { apply_id_order _1 }

      # Calculate pending_balance from filtered transactions (before pagination)
      # This ensures the balance matches what's visible in the filtered set
      @pending_balance = filtered_transactions.where(pending: true).sum(:amount)

      # Preserve the current page from the request parameters
      current_page = params[:page]&.to_i || 1
      @pagy, @transactions = pagy(filtered_transactions, page: current_page)
      @transactions = @transactions.decorate

      # Set the correct pagination URL with current page and filters
      pagination_params = { page: current_page }
      # Preserve any existing filters from session
      if session["filters"]&.dig("description")&.present?
        pagination_params[:description] = session["filters"]["description"]
      end
      if session["filters"]&.dig("account_id")&.present?
        pagination_params[:account_id] = session["filters"]["account_id"]
      end
      @pagy_url = account_transactions_path(@account) + "?" + pagination_params.to_query

      # Pre-calculate transaction groupings
      group_transactions_for_display

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
        format.json { render json: { success: false, errors: @transaction.errors.full_messages }, status: :unprocessable_content }
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
      
      # Build filtered transaction scope (before pagination)
      filtered_transactions = @account.transactions
                                      .with_attached_attachments
                                      .includes(:transaction_balance, :category)
                                      .then { search_by_description _1 }
                                      .then { apply_pending_order _1 }
                                      .then { apply_order _1 }
                                      .then { apply_id_order _1 }

      # Calculate pending_balance from filtered transactions (before pagination)
      # This ensures the balance matches what's visible in the filtered set
      @pending_balance = filtered_transactions.where(pending: true).sum(:amount)

      # Preserve the current page from the request parameters
      current_page = params[:page]&.to_i || 1
      @pagy, @transactions = pagy(filtered_transactions, page: current_page)
      @transactions = @transactions.decorate

      # Set the correct pagination URL with current page and filters
      pagination_params = { page: current_page }
      # Preserve any existing filters from session
      if session["filters"]&.dig("description")&.present?
        pagination_params[:description] = session["filters"]["description"]
      end
      if session["filters"]&.dig("account_id")&.present?
        pagination_params[:account_id] = session["filters"]["account_id"]
      end
      @pagy_url = account_transactions_path(@account) + "?" + pagination_params.to_query

      # Pre-calculate transaction groupings
      group_transactions_for_display

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
        format.json { render json: { success: false, errors: @transaction.errors.full_messages }, status: :unprocessable_content }
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

  def suggest_category
    description = params[:description].to_s
    suggestion = category_suggester.suggest(description)

    Rails.logger.info(
      "Category suggestion: description='#{description}', suggestion_source=#{suggestion&.source}, category_id=#{suggestion&.category&.id}, confidence=#{suggestion&.confidence}"
    )

    render json: {
      category: suggestion&.category&.name,
      category_id: suggestion&.category&.id,
      confidence: suggestion&.confidence,
      source: suggestion&.source,
      error: suggestion&.source == :ai_rate_limited ? "ai_rate_limited" : nil
    }, status: :ok
  end

  def update_date
    if @transaction.update_date_only(params[:date])
      render json: { success: true, trx_date: @transaction.trx_date }
    else
      render json: { success: false, errors: @transaction.errors.full_messages }, status: :unprocessable_content
    end
  end

  def update_attachment
    if params[:transaction][:attachments].present?
      # Handle multiple file uploads
      files = Array(params[:transaction][:attachments])
      uploaded_files = []
      
      files.each do |file|
        @transaction.attachments.attach(file)
        uploaded_files << file.original_filename
      end
      
      render json: {
        success: true,
        filenames: uploaded_files,
        has_attachments: @transaction.attachments.attached?,
        attachment_count: @transaction.attachments.count
      }
    else
      render json: {
        success: false,
        errors: ["No files were selected"]
      }, status: :unprocessable_content
    end
  rescue => e
    Rails.logger.error "Error in update_attachment: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: {
      success: false,
      errors: [ "An error occurred while updating the attachments: #{e.message}" ]
    }, status: :internal_server_error
  end

  def delete_attachment
    # Find the attachment by ID from the transaction's attachments
    attachment_id = params[:attachment_id]
    Rails.logger.info "Attempting to delete attachment ID: #{attachment_id}"
    
    begin
      # Find the attachment from this transaction's attachments
      attachment = @transaction.attachments.find_by(id: attachment_id)
      
      unless attachment
        Rails.logger.error "Attachment not found with ID: #{attachment_id} for transaction: #{@transaction.id}"
        render json: {
          success: false,
          errors: ["Attachment not found"]
        }, status: :not_found
        return
      end
      
      filename = attachment.filename.to_s
      Rails.logger.info "Found attachment: #{filename}"
      
      # Delete the attachment
      attachment.purge
      Rails.logger.info "Purge completed"
      
      # Reload the transaction to get fresh attachment count
      @transaction.reload
      new_count = @transaction.attachments.count
      Rails.logger.info "New attachment count: #{new_count}"
      
      # If we got here without an exception, the purge was successful
      render json: {
        success: true,
        message: "Attachment '#{filename}' deleted successfully",
        has_attachments: @transaction.attachments.attached?,
        attachment_count: new_count
      }
    rescue => e
      Rails.logger.error "Error in delete_attachment: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        success: false,
        errors: [ "An error occurred while deleting the attachment: #{e.message}" ]
      }, status: :internal_server_error
    end
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
          account_id: params[:transaction][:account_id],
          category_id: params[:transaction][:category_id]
        }
      elsif params[:transaction]&.key?(:description)
        { description: params[:transaction][:description] }
      elsif params[:transaction]&.key?(:category_id)
        { category_id: params[:transaction][:category_id] }
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
            .permit(:trx_date, :description, :amount, :trx_type, :memo, { attachments: [] }, :page, :locked, :transfer, :account_id, :pending, :category_id)
    end
  end

  def search_by_description(scope)
    session["filters"]&.dig("description")&.present? ? scope.where("UPPER(description) like UPPER(?)", "%#{session['filters']['description']}%") : scope
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
    @transfer_accounts = current_user.accounts.where("active = ?", "true").where("account_type != ?", "credit").where(
      "id != ?", account_id
    ).decorate
  end

  def find_transaction
    @transaction = @account.transactions.find(params[:id]).decorate
  end

  def load_categories
    @categories = Category.for_user(current_user).ordered
  end

  def category_suggester
    @category_suggester ||= CategorySuggester.new(user: current_user)
  end

  def apply_category_suggestion(transaction)
    return if transaction.category_id.present? || transaction.description.blank?

    suggestion = category_suggester.suggest(transaction.description)
    return if suggestion.nil?

    if suggestion.confidence >= 0.75
      transaction.category = suggestion.category
    else
      @category_suggestion = suggestion
    end
  end

  def group_transactions_for_display
    # Separate quick receipts from other transactions
    @quick_receipts = @transactions.select(&:quick_receipt?)
    @other_transactions = @transactions.reject(&:quick_receipt?)
    
    # Further separate other transactions into pending and non-pending
    @pending_transactions = @other_transactions.select(&:pending?)
    @non_pending_transactions = @other_transactions.reject(&:pending?)
    
    # Group non-pending transactions by date for desktop rendering
    @transactions_by_date = @non_pending_transactions.group_by(&:trx_date).transform_values do |transactions|
      transactions.sort_by(&:id).reverse
    end
  end
end
