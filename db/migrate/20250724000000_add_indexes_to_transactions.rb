class AddIndexesToTransactions < ActiveRecord::Migration[7.0]
  def change
    # Add index for pending transactions queries
    add_index :transactions, [:account_id, :pending], name: 'index_transactions_on_account_id_and_pending'
    
    # Add index for transaction date ordering
    add_index :transactions, [:account_id, :trx_date, :id], name: 'index_transactions_on_account_id_and_trx_date_and_id'
    
    # Add index for amount sum queries
    add_index :transactions, [:account_id, :pending, :amount], name: 'index_transactions_on_account_id_and_pending_and_amount'
  end
end