class CreateCategoryLookups < ActiveRecord::Migration[7.1]
  def change
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    create_table :category_lookups do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.text :description_norm, null: false
      t.integer :usage_count, null: false, default: 1
      t.datetime :last_used_at, null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.timestamps
    end

    add_index :category_lookups, [ :user_id, :description_norm ], unique: true, name: "index_category_lookups_on_user_and_description_norm"
    add_index :category_lookups, :description_norm, using: :gin, opclass: :gin_trgm_ops, name: "index_category_lookups_on_description_norm_trgm"
  end
end

