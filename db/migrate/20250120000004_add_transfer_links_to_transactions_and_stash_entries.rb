class AddTransferLinksToTransactionsAndStashEntries < ActiveRecord::Migration[6.0]
  def change
    add_column :transactions, :counterpart_transaction_id, :bigint, null: true
    add_index :transactions, :counterpart_transaction_id
    add_foreign_key :transactions, :transactions, column: :counterpart_transaction_id

    add_column :stash_entries, :transaction_id, :bigint, null: true
    add_index :stash_entries, :transaction_id
    add_foreign_key :stash_entries, :transactions, column: :transaction_id
  end
end

