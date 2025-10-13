class AddDefaultAccountIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :default_account_id, :bigint
    add_foreign_key :users, :accounts, column: :default_account_id
    add_index :users, :default_account_id
  end
end
