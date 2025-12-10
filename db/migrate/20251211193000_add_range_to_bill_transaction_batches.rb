class AddRangeToBillTransactionBatches < ActiveRecord::Migration[8.0]
  def change
    add_column :bill_transaction_batches, :range_start_date, :date
    add_column :bill_transaction_batches, :range_end_date, :date

    change_column_null :bill_transaction_batches, :period_month, true

    add_index :bill_transaction_batches, [:user_id, :range_start_date, :range_end_date], name: "index_batches_on_user_and_range"
  end
end


