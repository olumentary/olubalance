class CreateBills < ActiveRecord::Migration[8.0]
  def change
    create_table :bills do |t|
      t.string :bill_type, null: false
      t.string :category, null: false
      t.string :description, null: false
      t.string :frequency, null: false, default: "monthly"
      t.integer :day_of_month, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.text :notes
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :bills, [:user_id, :bill_type]
    add_index :bills, [:user_id, :frequency]
    add_index :bills, [:user_id, :day_of_month]
  end
end

