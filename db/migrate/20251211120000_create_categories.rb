class CreateCategories < ActiveRecord::Migration[7.1]
  DEFAULT_CATEGORY_NAMES = [
    "Groceries",
    "Dining",
    "Utilities",
    "Rent",
    "Mortgage",
    "Transportation",
    "Fuel",
    "Healthcare",
    "Insurance",
    "Entertainment",
    "Travel",
    "Income",
    "Savings",
    "Investments",
    "Subscriptions",
    "Education",
    "Gifts",
    "Miscellaneous"
  ].freeze

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

    reversible do |dir|
      dir.up do
        values_sql = DEFAULT_CATEGORY_NAMES.map do |name|
          "(#{connection.quote(name)}, 0, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
        end.join(",\n")

        execute <<~SQL
          INSERT INTO categories (name, kind, user_id, created_at, updated_at)
          VALUES
          #{values_sql}
          ON CONFLICT DO NOTHING
        SQL
      end
    end
  end
end

