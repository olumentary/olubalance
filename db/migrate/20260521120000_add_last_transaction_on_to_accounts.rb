# frozen_string_literal: true

class AddLastTransactionOnToAccounts < ActiveRecord::Migration[8.1]
  def up
    add_column :accounts, :last_transaction_on, :date
    add_index :accounts, :last_transaction_on

    # Backfill from each account's most recent non-pending transaction.
    Account.find_each do |account|
      date = account.transactions.where(pending: false).maximum(:trx_date)
      account.update_columns(last_transaction_on: date) if date
    end
  end

  def down
    remove_index :accounts, :last_transaction_on
    remove_column :accounts, :last_transaction_on
  end
end
