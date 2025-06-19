class AddQuickReceiptToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :quick_receipt, :boolean
  end
end
