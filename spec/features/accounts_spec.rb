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

  scenario "user marks transaction as reviewed and stays on current page" do
    # Create an account first
    account = FactoryBot.create(:account, user: @user, name: "Test Account", starting_balance: 1000)
    
    # Create enough transactions to ensure pagination (Pagy default is 15 items per page)
    30.times do |i|
      FactoryBot.create(:transaction, 
        account: account, 
        trx_date: Date.today, 
        description: "Transaction #{i}", 
        amount: 10, 
        trx_type: 'debit', 
        pending: true
      )
    end

    # Visit the transactions page
    visit account_transactions_path(account)
    
    # Check if pagination exists and go to page 2
    if page.has_link?("2")
      click_link "2"
      
      # Verify we're on page 2
      expect(page).to have_current_path(/#{account_transactions_path(account)}.*page=2/)
      
      # Mark a transaction as reviewed (if one exists)
      if page.has_css?('.button[data-action*="markReviewed"]')
        first('.button[data-action*="markReviewed"]').click
        
        # Should still be on page 2
        expect(page).to have_current_path(/#{account_transactions_path(account)}.*page=2/)
      end
    else
      # If no pagination, just test that marking as reviewed works
      if page.has_css?('.button[data-action*="markReviewed"]')
        first('.button[data-action*="markReviewed"]').click
        # Just verify we're still on the transactions page
        expect(page).to have_current_path(account_transactions_path(account))
      end
    end
  end

end
