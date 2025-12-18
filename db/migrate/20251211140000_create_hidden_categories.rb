# frozen_string_literal: true

class CreateHiddenCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :hidden_categories do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true

      t.timestamps
    end

    add_index :hidden_categories, %i[user_id category_id], unique: true
  end
end

