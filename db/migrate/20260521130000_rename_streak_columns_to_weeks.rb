# frozen_string_literal: true

# Streak semantics changed from daily to weekly (Sunday–Saturday cycle).
# Renaming the columns and zeroing existing values — carrying a count
# forward would silently re-interpret "N days" as "N weeks" and mislead
# users about their progress. Acceptable since engagement state is
# regeneratively rebuilt week-over-week.
class RenameStreakColumnsToWeeks < ActiveRecord::Migration[8.1]
  def up
    rename_column :users, :current_streak_days, :current_streak_weeks
    rename_column :users, :longest_streak_days, :longest_streak_weeks
    User.update_all(current_streak_weeks: 0, longest_streak_weeks: 0)
  end

  def down
    rename_column :users, :current_streak_weeks, :current_streak_days
    rename_column :users, :longest_streak_weeks, :longest_streak_days
  end
end
