# frozen_string_literal: true

# Stashes can be used to set money aside within an account
class Stash < ApplicationRecord
  belongs_to :account
  has_many :stash_entries, dependent: :delete_all

  validates :name, presence: true,
                   length: { maximum: 50, minimum: 2 },
                   uniqueness: { scope: :account_id }

  validates :goal, presence: true,
                   numericality: { greater_than_or_equal_to: :balance }

  validates :balance, numericality: { greater_than_or_equal_to: 0 }

  before_destroy :unstash

  private

  # Create an account transaction to return any stashed money
  # to the Account balance when a Stash is deleted
  def unstash
    return unless balance.positive?

    transaction = account.transactions.build(
      trx_type: "credit",
      trx_date: Time.current,
      category_id: Category.transfer_category.id,
      description: "Transfer from #{name} Stash (Stash Deleted)",
      amount: balance.abs,
      skip_pending_default: true,
      locked: true,
      transfer: true
    )

    transaction.save!
  rescue StandardError => e
    Rails.logger.error "Failed to unstash funds for stash ##{id}: #{e.message}"
    throw(:abort)
  end
end
