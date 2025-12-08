# frozen_string_literal: true

# Records money added and removed from a stash
class StashEntry < ApplicationRecord
  STASH_ADD_DESC = "Stash funded"
  STASH_REMOVE_DESC = "Stash withdrawal"

  belongs_to :stash
  belongs_to :linked_transaction, class_name: "Transaction", foreign_key: "transaction_id", optional: true

  attr_accessor :stash_action

  validates :stash_action, presence: true,
                           inclusion: { in: %w[add remove] }
  validates :amount, presence: true,
                     numericality: { greater_than: 0 }

  validate :stash_balance_out_of_bounds

  # before_validation :set_stash
  before_save :set_stash
  before_save :initialize_stash_entry
  after_create :update_stash_balance
  after_create :create_stash_transaction

  private

  def stash_balance_out_of_bounds
    return unless amount.present?

    validation_stash = Stash.find(stash_id)
    validation_amount = stash_action == "remove" ? -amount.abs : amount.abs

    errors.add(:amount, "can't cause the stash balance to become negative") \
      if (validation_stash.balance + validation_amount).negative?

    errors.add(:amount, "can't cause the stash balance to exceed the goal") \
      if (validation_stash.balance + validation_amount) > validation_stash.goal
  end

  def set_stash
    @stash = Stash.find(stash_id)
  end

  def initialize_stash_entry
    self.amount = stash_action == "remove" ? -amount.abs : amount.abs # convert amount
    self.description = stash_action == "add" ? STASH_ADD_DESC : STASH_REMOVE_DESC # set appropriate description
    self.stash_entry_date = Time.current # default to current date/time
  end

  def update_stash_balance
    @stash.update(balance: @stash.balance + amount)
  end

  def create_stash_transaction
    desc_add = "Transfer to " + @stash.name + " Stash"
    desc_remove = "Transfer from " + @stash.name + " Stash"

    transaction = Transaction.new
    transaction.trx_type = stash_action == "add" ? "debit" : "credit"
    transaction.trx_date = stash_entry_date || Time.current
    transaction.account_id = @stash.account_id
    transaction.description = stash_action == "add" ? desc_add : desc_remove
    transaction.amount = amount.abs
    transaction.skip_pending_default = true
    transaction.locked = true
    transaction.transfer = true
    transaction.save

    # Link the transaction to this stash entry
    update_column(:transaction_id, transaction.id)
  end
end
