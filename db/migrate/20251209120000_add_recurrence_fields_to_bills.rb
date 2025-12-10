class AddRecurrenceFieldsToBills < ActiveRecord::Migration[7.0]
  def up
    add_column :bills, :biweekly_mode, :string
    add_column :bills, :second_day_of_month, :integer
    add_column :bills, :biweekly_anchor_weekday, :integer
    add_column :bills, :biweekly_anchor_date, :date
    add_column :bills, :next_occurrence_month, :integer

    backfill_biweekly_defaults
    backfill_next_occurrence_month
  end

  def down
    remove_column :bills, :biweekly_mode
    remove_column :bills, :second_day_of_month
    remove_column :bills, :biweekly_anchor_weekday
    remove_column :bills, :biweekly_anchor_date
    remove_column :bills, :next_occurrence_month
  end

  private

  def backfill_biweekly_defaults
    execute <<~SQL.squish
      UPDATE bills
      SET biweekly_mode = 'every_other_week',
          biweekly_anchor_date = (
            date_trunc('month', current_date)
            + (LEAST(day_of_month, date_part('day', (date_trunc('month', current_date) + interval '1 month - 1 day'))) - 1) * interval '1 day'
          )::date,
          biweekly_anchor_weekday = EXTRACT(DOW FROM (
            date_trunc('month', current_date)
            + (LEAST(day_of_month, date_part('day', (date_trunc('month', current_date) + interval '1 month - 1 day'))) - 1) * interval '1 day'
          ))
      WHERE frequency = 'bi_weekly'
        AND biweekly_mode IS NULL;
    SQL
  end

  def backfill_next_occurrence_month
    execute <<~SQL.squish
      UPDATE bills
      SET next_occurrence_month = EXTRACT(MONTH FROM current_date)
      WHERE frequency IN ('quarterly', 'annual')
        AND next_occurrence_month IS NULL;
    SQL
  end
end

