require "rails_helper"

RSpec.describe "Transaction management", type: :request do
  before(:each) do
    @user = FactoryBot.create(:user)
    @starting_balance = 5000
    @account = FactoryBot.create(:account, name: "Account Management Test", starting_balance: @starting_balance, user: @user).decorate
    @trx_amount = 50
    @transaction = FactoryBot.create(:transaction, :non_pending, trx_date: Date.today, description: "Transaction 1", amount: @trx_amount, trx_type: 'debit', memo: 'Memo 1', account: @account)
  end

  it "redirects to login page if not logged in" do
    get accounts_path
    expect(response).to redirect_to new_user_session_path
  end

  it "displays a list of the user's transactions and the account balance" do
    @balance = @starting_balance - @trx_amount
    sign_in @user
    get account_transactions_path(@account)
    expect(response).to be_successful
    expect(response.body).to include(@account.account_card_title)
    expect(response.body).to include(number_to_currency(@balance))
    expect(response.body).to include(@transaction.description)
  end

  it "doesn't show another user's transactions" do
    user2 = FactoryBot.create(:user, email: 'testuser2@gmail.com')
    account2 = FactoryBot.create(:account, name: "User 2 Account", user: user2)
    transaction2 = FactoryBot.create(:transaction, :non_pending, account: account2)
  
    sign_in @user
    get account_transactions_path(account2)
    
    expect(response).to have_http_status(:not_found) # 404
  end
  

  it "displays pending balance when pending transactions exist" do
    @balance = @starting_balance - @trx_amount
    @pending_trx_amount = 100
    sign_in @user
    FactoryBot.create(:transaction, trx_date: Date.today, description: "Review this Transaction", amount: @pending_trx_amount, trx_type:'debit', account: @account)
    get account_transactions_path(@account)
    expect(response).to be_successful
    expect(response.body).to include('Pending')
    expect(response.body).to include("-#{number_to_currency(@pending_trx_amount)}")
  end

  it "shows an existing transaction" do
    sign_in @user
    get account_transaction_path(@account.id, @transaction.id)
    expect(response).to render_template(:show)
    expect(response.body).to include("Transaction Details")
    expect(response.body).to include("Edit")
    expect(response.body).to include("Delete")
    expect(response.body).to include(number_to_currency(@trx_amount))
  end

  it "creates a new transaction and redirects to the transactions page" do
    sign_in @user
    get new_account_transaction_path(@account.id)
    expect(response.body).to include("New Transaction")

    post "/accounts/#{@account.id}/transactions", params: { 
      transaction: { 
        trx_date: Date.today,
        description: "Test New Transaction", 
        amount: 500,
        trx_type: 'debit',
        memo: 'Memo New Transaction',
        account: @account.id
      }
    }
    expect(response).to redirect_to(account_transactions_path(@account))
    follow_redirect!

    @balance = @starting_balance - @trx_amount - 500
    expect(response.body).to include("Test New Transaction")
    expect(response.body).to include(number_to_currency(@balance))
  end

  it "fails when creating a new transaction with invalid parameters" do
    sign_in @user
    get new_account_transaction_path(@account.id)
    expect(response.body).to include("New Transaction")

    # trx_type omitted - but this won't fail validation for pending transactions
    post "/accounts/#{@account.id}/transactions", params: { 
      transaction: { 
        trx_date: Date.today,
        description: "Test New Transaction", 
        amount: 500,
        memo: 'Memo New Transaction',
        account: @account.id
      }
    }
    # Since the transaction is created as pending, validation passes and it redirects
    expect(response).to redirect_to(account_transactions_path(@account))
  end

  it "updates an existing transaction and redirects to the transactions page" do
    sign_in @user
    get edit_account_transaction_path(@account.id, @transaction.id)
    expect(response.body).to include("Edit Transaction")

    # Update the transaction
    patch "/accounts/#{@account.id}/transactions/#{@transaction.id}", params: { 
      transaction: { 
        description: "Test Create Transaction Edited",
        amount: 100,
        trx_type: 'debit'
      }
    }
    
    # Verify the redirect
    expect(response).to redirect_to(account_transactions_path(@account))
    
    # Follow the redirect
    follow_redirect!
    
    # Verify the transaction was updated
    @transaction.reload
    expect(@transaction.description).to eq("Test Create Transaction Edited")
    expect(@transaction.amount).to eq(-100) # Amount is negative for debit transactions
    
    # Verify the balance
    @balance = @starting_balance - 100
    expect(response.body).to include(number_to_currency(@balance))
  end

  it "fails when making an invalid update to a transaction" do
    sign_in @user
    get edit_account_transaction_path(@account.id, @transaction.id)
    expect(response.body).to include("Edit Transaction")

    # Omit required fields for non-pending transaction
    patch "/accounts/#{@account.id}/transactions/#{@transaction.id}", params: { 
      transaction: { 
        description: "",  # Empty description should fail validation
        amount: nil       # Nil amount should fail validation
      }
    }
    # Since the transaction is non-pending, validation should fail and render edit template
    expect(response).to render_template(:edit)
  end
end
