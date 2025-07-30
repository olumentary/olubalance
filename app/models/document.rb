# frozen_string_literal: true

class Document < ApplicationRecord
  belongs_to :attachable, polymorphic: true
  has_many_attached :attachments

  CATEGORIES = %w[Statements Account\ Documentation Correspondence Legal Taxes Other].freeze

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :document_date, presence: true
  validates :tax_year, presence: true, numericality: { only_integer: true, greater_than: 1900, less_than: 2100 }, if: :tax_document?
  validates :attachments, presence: true, on: :update

  scope :by_category, ->(category) { where(category: category) if category.present? }
  scope :by_tax_year, ->(year) { where(tax_year: year) if year.present? }
  scope :by_date_range, ->(start_date, end_date) { 
    where(document_date: start_date..end_date) if start_date.present? && end_date.present? 
  }

  def tax_document?
    category == 'Taxes'
  end

  def level
    case attachable_type
    when 'User'
      'User'
    when 'Account'
      'Account'
    else
      'Unknown'
    end
  end

  def account_name
    case attachable_type
    when 'Account'
      attachable.name
    when 'User'
      'N/A'
    else
      'Unknown'
    end
  end
end 