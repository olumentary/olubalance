require "rails_helper"

RSpec.describe "Account management", type: :request do
  before(:each) do
    @user = FactoryBot.create(:user)
    @account = FactoryBot.create(:account, name: "Account Management Test", starting_balance: 5000, user: @user)
    @account_starting_balance = "$5,000.00"
  end

  it "redirects to login page when not authenticated" do
    get accounts_path
    expect(response).to redirect_to new_user_session_path
  end

  it "displays a list of the user's accounts" do
    sign_in @user
    get accounts_path
    expect(response).to be_successful
    expect(response.body).to include(@account.name)
    expect(response.body).to include(@account_starting_balance)
  end

  it "doesn't show another user's accounts" do
    user2 = FactoryBot.create(:user, email: 'testuser2@gmail.com')
    account2 = FactoryBot.create(:account, name: "User 2 Account", user: user2)

    sign_in @user
    get accounts_path
    expect(response).to be_successful
    expect(response.body).to_not include("User 2 Account")
  end

  it "creates a new account and redirects to the accounts page" do
    sign_in @user
    get new_account_path
    expect(response.body).to include("New Account")

    post "/accounts", params: { account: { name: "Test Create Account", starting_balance: 3500.50, user: @user.id } }
    expect(response).to redirect_to(accounts_path)
    follow_redirect!

    expect(response.body).to include("Test Create Account")
    expect(response.body).to include("$3,500.50")
  end

  it "updates an existing account and redirects to the accounts page" do
    sign_in @user
    get edit_account_path(id: @account.id)
    expect(response.body).to include("Edit Account")

    patch "/accounts/#{@account.id}", params: { account: { name: "Test Create Account Edited", last_four: "1111" } }
    expect(response).to redirect_to(accounts_path)
    follow_redirect!

    expect(response.body).to include("Test Create Account Edited")
    expect(response.body).to include(@account_starting_balance)
    expect(response.body).to include("1111")
  end

  it "deactivates an existing account and activates an inactive account" do
    sign_in @user

    # Deactivate the account and check that it is not present on main accounts page
    get deactivate_account_path(id: @account.id)

    expect(response).to redirect_to(accounts_path)
    follow_redirect!

    expect(response.body).to_not include(@account.name)
    expect(response.body).to_not include(@account_starting_balance)

    # Visit the inactive accounts page and check that the inactive account is present
    get accounts_inactive_path
    expect(response.body).to include(@account.name)
    expect(response.body).to include(@account_starting_balance)

    # Reactivate the account and check that the account appears back on the main accounts page
    get activate_account_path(id: @account.id)

    expect(response).to redirect_to(accounts_path)
    follow_redirect!

    expect(response.body).to include(@account.name)
    expect(response.body).to include(@account_starting_balance)

    # Go back to the inactive accounts page and ensure the reactivated account is not listed
    get accounts_inactive_path
    expect(response.body).to_not include(@account.name)
    expect(response.body).to_not include(@account_starting_balance)
  end
end
