# frozen_string_literal: true

class Document < ApplicationRecord
  belongs_to :attachable, polymorphic: true
  has_one_attached :attachment

  CATEGORIES = %w[Statements Account\ Documentation Correspondence Legal Taxes Other].freeze

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :document_date, presence: true
  validates :description, length: { maximum: 500 }
  validates :tax_year, presence: true, numericality: { only_integer: true, greater_than: 1900, less_than: 2100 }, if: :tax_document?
  validates :attachment, presence: true, on: :update

  scope :by_category, ->(category) { where(category: category) if category.present? }
  scope :by_level, ->(level) { where(attachable_type: level) if level.present? }
  scope :by_account, ->(account_id) { where(attachable_type: 'Account', attachable_id: account_id) if account_id.present? }
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