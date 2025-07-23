require 'rails_helper'

RSpec.feature "Logins", type: :feature do
  scenario "user logs in successfully" do
    user = FactoryBot.create(:user)

    visit root_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    click_button "Login"

    expect(page).to have_content("Accounts")
  end

  scenario "user logs in unsuccessfully" do
    user = FactoryBot.create(:user)

    visit root_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: 'asdfasdf'
    click_button "Login"

    expect(page).to have_content("Login to olubalance")
  end
end
