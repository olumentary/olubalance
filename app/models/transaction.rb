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
                       inclusion: { in: %w[credit debit] }
  validates :trx_date, presence: true
  validates :description, presence: true, length: { maximum: 150 }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :memo, length: { maximum: 500 }

  # before_post_process :rename_file

  before_create :set_pending
  before_save :convert_amount
  before_save :set_account
  after_create :update_account_balance_create
  after_update :update_account_balance_edit
  after_destroy :update_account_balance_destroy

  scope :with_balance, -> { includes(:transaction_balance).references(:transaction_balance) }
  scope :desc, -> { order("pending DESC, trx_date DESC, id DESC") }
  scope :recent, -> { where("created_at > ?", 3.days.ago).order("trx_date, id") }
  scope :pending, -> { where(pending: true).order("trx_date, id") }

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

  private

  def set_pending
    return if skip_pending_default
    self.pending = true if new_record?
  end

  def convert_amount
    self.amount = -amount.abs if trx_type == "debit"
  end

  def set_account
    @account = Account.find(account_id)
  end

  def update_account_balance_create
    @account.update(current_balance: @account.current_balance + amount)
  end

  def update_account_balance_edit
    @account = Account.find(account_id)
    @account.update(current_balance: @account.current_balance - amount_before_last_save + amount) \
      if saved_change_to_amount?
  end

  def update_account_balance_destroy
    @account = Account.find(account_id)
    # Rails 5.2 - amount_was is still valid in after_destroy callbacks
    @account.update(current_balance: @account.current_balance - amount_was)
  end
end
