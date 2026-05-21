class AddInterestSchedulingToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :statement_day, :integer
    add_column :accounts, :last_interest_charged_on, :date
  end
end
