class CreateCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.integer :kind, null: false, default: 0
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end

    add_index :categories, "LOWER(name), COALESCE(user_id, 0)", unique: true, name: "index_categories_on_user_and_lower_name"

    change_table :transactions, bulk: true do |t|
      t.references :category, null: true, foreign_key: { on_delete: :nullify }
    end
  end
end

