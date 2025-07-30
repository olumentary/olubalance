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
    @documents = @documents.by_tax_year(params[:tax_year]) if params[:tax_year].present?
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
    else
      @documents = @documents.order(document_date: sort_direction)
    end

    @categories = Document::CATEGORIES
    @tax_years = Document.where.not(tax_year: nil).distinct.pluck(:tax_year).sort.reverse
  end
end 