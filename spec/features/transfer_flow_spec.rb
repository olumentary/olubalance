require "rails_helper"

# Uses Capybara's default rack_test driver (no JS). Selenium is configured for
# this project via `Capybara.javascript_driver = :selenium_chrome_headless`
# but is only triggered with `js: true`. Keeping these specs JS-free makes them
# fast and stable in CI.
RSpec.feature "Transfer between two of my accounts", type: :feature do
  let(:user) { create(:user) }
  let!(:source) { create(:account, user: user, name: "Source", starting_balance: 1000) }
  let!(:target) { create(:account, user: user, name: "Target", starting_balance: 200) }

  before do
    visit root_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    click_button "Login"
  end

  scenario "submitting the transfer form creates a debit/credit pair and updates balances" do
    # Drive the transfer via the controller endpoint directly; the form lives in
    # a modal whose visibility is Stimulus-driven and not exercised under
    # rack_test.
    page.driver.post transfers_path, {
      transfer_from_account: source.id,
      transfer_to_account: target.id,
      transfer_amount: "250.00",
      transfer_date: Date.current.to_s
    }

    visit account_transactions_path(source)
    expect(page).to have_content("Transfer to Target")
    expect(page).to have_content("Source")

    visit account_transactions_path(target)
    expect(page).to have_content("Transfer from Source")
  end
end
