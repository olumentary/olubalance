# frozen_string_literal: true

class CreateDataImports < ActiveRecord::Migration[8.1]
  def change
    create_table :data_imports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.integer :progress, null: false, default: 0
      t.string :step
      t.text :error_message

      t.timestamps
    end

    add_index :data_imports, [ :user_id, :created_at ]
  end
end
