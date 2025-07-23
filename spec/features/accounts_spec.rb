require 'rails_helper'

RSpec.feature "Accounts", type: :feature do
  before do
    @user = FactoryBot.create(:user)

    visit root_path
    fill_in "user_email", with: @user.email
    fill_in "user_password", with: @user.password
    click_button "Login"
  end 

  scenario "user creates a new account and renames it" do
    expect(page).to have_content("It looks like you don't have any accounts added.")

    expect {
      within "p.level-item.is-hidden-mobile" do
        click_link "New"
      end
      fill_in "account_name", with: "Test Account"
      fill_in "account_last_four", with: "1234"
      fill_in "account_starting_balance", with: "5000.00"
      click_button "Create"
      expect(page).to have_content "Test Account"
      expect(page).to have_content "$5,000.00"
    }.to change(@user.accounts, :count).by(1)

    click_link "Edit"
    fill_in "account_name", with: "Different Account Name"
    click_button "Update"
    expect(page).to have_content "Different Account Name"
  end

  scenario "user creates a new account and deactivates it" do
    expect(page).to have_content("It looks like you don't have any accounts added.")

    expect {
      within "p.level-item.is-hidden-mobile" do
        click_link "New"
      end
      fill_in "account_name", with: "Test Account"
      fill_in "account_last_four", with: "1234"
      fill_in "account_starting_balance", with: "5000.00"
      click_button "Create"
      expect(page).to have_content "Test Account"
      expect(page).to have_content "$5,000.00"
    }.to change(@user.accounts, :count).by(1)

    within('.account-card') do
      find('.card-footer-item.modal-button').click
    end
    expect(page).to have_content("Deactivate Test Account?")

  end

end
