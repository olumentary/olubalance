class RemoveStreakColumnsFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :current_streak_weeks, :integer
    remove_column :users, :longest_streak_weeks, :integer
    remove_column :users, :streak_last_evaluated_on, :date
  end
end
