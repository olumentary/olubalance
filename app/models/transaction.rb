# frozen_string_literal: true

# A transaction record which belongs to one account. Can have one attached file
class Transaction < ApplicationRecord
  belongs_to :account
  has_one :transaction_balance

  has_one_attached :attachment

  # Link running_balance to view
  delegate :running_balance, to: :transaction_balance

  attr_accessor :trx_type, :skip_pending_default

  # default_scope { order('trx_date, id DESC') }
  validates :trx_type, presence: { message: "Please select debit or credit" },
                       inclusion: { in: %w[credit debit] },
                       unless: :pending?
  validates :trx_date, presence: true
  validates :description, presence: true, length: { maximum: 150 }, unless: :pending?
  validates :amount, presence: true, unless: :pending?
  validates :memo, length: { maximum: 500 }
  validate :attachment_required_for_quick_receipt
  validate :require_fields_when_reviewed
  validate :validate_amount_for_reviewed_transactions

  # before_post_process :rename_file

  before_create :set_pending
  before_validation :set_trx_type_for_existing_records
  before_save :convert_amount
  before_save :set_account
  before_save :clear_quick_receipt_when_complete, if: :quick_receipt?
  after_create :update_account_balance_create
  after_update :update_account_balance_edit
  after_destroy :update_account_balance_destroy

  scope :with_balance, -> { includes(:transaction_balance).references(:transaction_balance) }
  scope :desc, -> { order("pending DESC, trx_date DESC, id DESC") }
  scope :recent, -> { where("created_at > ?", 3.days.ago).order("trx_date, id") }
  scope :pending, -> { where(pending: true).order("trx_date, id") }
  scope :non_pending, -> { where(pending: false).order("trx_date DESC, id DESC") }

  scope :search, lambda { |query|
    query = sanitize_sql_like(query)
    where(arel_table[:description]
            .lower
            .matches("%#{query.downcase}%"))
  }

  # Determine the transaction_type for existing records based on amount
  def transaction_type
    # new_record? is checked first to prevent a nil class error
    return %w[Credit credit] if !new_record? && amount >= 0

    %w[Debit debit]
  end

  def update_date_only(date)
    update_columns(trx_date: date, updated_at: Time.current)
  end

  private

  def set_pending
    return if skip_pending_default
    self.pending = true if new_record?
  end

  def set_trx_type_for_existing_records
    if !new_record? && amount.present? && trx_type.blank?
      if quick_receipt?
        self.trx_type = 'debit'
      else
        self.trx_type = amount >= 0 ? 'credit' : 'debit'
      end
    end
  end

  def convert_amount
    return if amount.nil?

    # If trx_type is set, use it to determine the sign
    if trx_type.present?
      # Convert amount based on trx_type
      if trx_type == "debit"
        self.amount = -amount.abs
      else
        self.amount = amount.abs
      end
    else
      # If no trx_type is set, preserve the existing sign or determine from current amount
      if !new_record? && amount_was.present?
        # Preserve the sign of the existing amount
        self.amount = amount_was < 0 ? -amount.abs : amount.abs
      else
        # For new records without trx_type, assume positive (will be handled by validations)
        self.amount = amount.abs
      end
    end
  end

  def set_account
    return if trx_date_changed? && !amount_changed? && !description_changed?
    @account = Account.find(account_id)
  end

  def clear_quick_receipt_when_complete
    # Set quick_receipt to false if both description and amount are present
    if description.present? && amount.present?
      self.quick_receipt = false
    end
  end

  def update_account_balance_create
    return if amount.nil?
    @account = Account.find(account_id)
    @account.update(current_balance: @account.current_balance + amount)
  end

  def update_account_balance_edit
    return if amount.nil?
    @account = Account.find(account_id)

    if amount_before_last_save.nil?
      # First time setting an amount (e.g., from quick receipt)
      @account.update(current_balance: @account.current_balance + amount)
    else
      # Updating an existing amount
      @account.update(current_balance: @account.current_balance - amount_before_last_save + amount) \
        if saved_change_to_amount?
    end
  end

  def update_account_balance_destroy
    return if amount_was.nil?
    @account = Account.find(account_id)
    # Rails 5.2 - amount_was is still valid in after_destroy callbacks
    @account.update(current_balance: @account.current_balance - amount_was)
  end

  def attachment_required_for_quick_receipt
    # Only require attachment for quick receipts when creating new records
    # or when the attachment is being explicitly removed
    if quick_receipt? && attachment.blank? && (new_record? || attachment.attached? == false)
      errors.add(:attachment, "is required for quick receipt transactions")
    end
  end

  def require_fields_when_reviewed
    # Only run if being marked as reviewed (pending: false or changed from true to false)
    if (!pending? || (will_save_change_to_pending? && !pending))
      errors.add(:trx_date, "can't be blank") if trx_date.blank?
      errors.add(:description, "can't be blank") if description.blank?
      errors.add(:amount, "can't be blank") if amount.blank?
      # Only require attachment when marking as reviewed (not when creating new transactions)
      if will_save_change_to_pending? && !pending?
        errors.add(:attachment, "must be attached when marking as reviewed") unless attachment.attached?
      end
    end
  end

  def validate_amount_for_reviewed_transactions
    return if pending? || amount.blank? || new_record?
    
    if trx_type == 'debit' && amount > 0
      errors.add(:amount, "must be negative for debit transactions")
    elsif trx_type == 'credit' && amount < 0
      errors.add(:amount, "must be positive for credit transactions")
    end
  end
end
