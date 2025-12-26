# frozen_string_literal: true

class AddCategoryToBills < ActiveRecord::Migration[8.0]
  def up
    add_reference :bills, :category, foreign_key: true

    # Migrate existing bills to "Miscellaneous" global category
    misc_category = Category.find_by(name: 'Miscellaneous', user_id: nil)
    if misc_category
      execute <<-SQL
        UPDATE bills SET category_id = #{misc_category.id}
      SQL
    end

    remove_column :bills, :category
  end

  def down
    add_column :bills, :category, :string, null: false, default: 'misc'

    remove_reference :bills, :category
  end
end

