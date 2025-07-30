# frozen_string_literal: true

class DocumentsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Get all documents for the current user (both user-level and account-level)
    @documents = Document.joins("LEFT JOIN accounts ON documents.attachable_id = accounts.id AND documents.attachable_type = 'Account'")
                        .where("(documents.attachable_type = 'User' AND documents.attachable_id = ?) OR (documents.attachable_type = 'Account' AND accounts.user_id = ?)", 
                               current_user.id, current_user.id)
                        .includes(:attachable)

    # Apply filters
    @documents = @documents.by_category(params[:category]) if params[:category].present?
    @documents = @documents.by_level(params[:level]) if params[:level].present?
    @documents = @documents.by_account(params[:account_id]) if params[:account_id].present?
    @documents = @documents.by_date_range(params[:start_date], params[:end_date]) if params[:start_date].present? && params[:end_date].present?

    # Apply sorting
    sort_column = params[:sort] || 'document_date'
    sort_direction = params[:direction] == 'asc' ? 'asc' : 'desc'
    
    case sort_column
    when 'category'
      @documents = @documents.order(category: sort_direction, document_date: :desc)
    when 'level'
      @documents = @documents.order(attachable_type: sort_direction, document_date: :desc)
    when 'account_name'
      @documents = @documents.order("accounts.name #{sort_direction}, document_date DESC")
    when 'description'
      @documents = @documents.order(description: sort_direction, document_date: :desc)
    when 'filename'
      # Sort by filename - one attachment per document
      @documents = @documents.joins("LEFT JOIN active_storage_attachments ON active_storage_attachments.record_id = documents.id AND active_storage_attachments.record_type = 'Document'")
                            .order("active_storage_attachments.name #{sort_direction}, document_date DESC")
    else
      @documents = @documents.order(document_date: sort_direction)
    end

    @categories = Document::CATEGORIES
    @levels = ['User', 'Account']
    @accounts = current_user.accounts.order(:name)
  end
end 