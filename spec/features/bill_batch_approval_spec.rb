require "rails_helper"

RSpec.feature "Bill batch preview → generate → undo", type: :feature do
  let(:user) { create(:user) }
  let!(:account) { create(:account, user: user, name: "Main", starting_balance: 5_000) }
  let(:category) { create(:category, :global, name: "Utilities") }
  let!(:bill) {
    create(:bill, user: user, account: account, category: category,
                  description: "Power", amount: 90, day_of_month: 15)
  }

  before do
    visit root_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    click_button "Login"
  end

  scenario "preview shows the bill; generate creates a batch; destroy undoes it" do
    visit new_transactions_batch_path(start_date: "2026-04-01", end_date: "2026-04-30")
    expect(page).to have_content("Power")

    expect {
      page.driver.post transactions_batches_path, start_date: "2026-04-01", end_date: "2026-04-30"
    }.to change { BillTransactionBatch.count }.by(1)
     .and change { Transaction.count }.by(1)

    batch = BillTransactionBatch.last
    expect {
      page.driver.delete transactions_batch_path(batch)
    }.to change { BillTransactionBatch.count }.by(-1)
  end
end
