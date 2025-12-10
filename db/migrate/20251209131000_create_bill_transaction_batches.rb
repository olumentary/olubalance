class CreateBillTransactionBatches < ActiveRecord::Migration[8.0]
  def change
    create_table :bill_transaction_batches do |t|
      t.references :user, null: false, foreign_key: true
      t.string :reference, null: false
      t.date :period_month, null: false
      t.integer :transactions_count, null: false, default: 0
      t.decimal :total_amount, precision: 12, scale: 2, null: false, default: 0

      t.timestamps
    end

    add_index :bill_transaction_batches, :reference, unique: true
    add_index :bill_transaction_batches, [:user_id, :period_month]

    add_column :transactions, :batch_reference, :string
    add_reference :transactions, :bill_transaction_batch, foreign_key: true, index: true

    add_index :transactions, :batch_reference
  end
end


