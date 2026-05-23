# frozen_string_literal: true

class AddStreakToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :current_streak_days, :integer, default: 0, null: false
    add_column :users, :longest_streak_days, :integer, default: 0, null: false
    add_column :users, :streak_last_evaluated_on, :date
  end
end
