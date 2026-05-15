require "rails_helper"

RSpec.describe "Stash entry management", type: :request do
  let(:user)    { create(:user) }
  let(:account) { create(:account, user: user, starting_balance: BigDecimal("1000")) }
  let!(:stash) {
    Stash.create!(account: account, name: "Vacation", description: "summer trip",
                  goal: BigDecimal("1000"), balance: BigDecimal("0"))
  }

  describe "GET /accounts/:account_id/stashes/:stash_id/stash_entries/new" do
    it "redirects to login when not signed in" do
      get new_account_stash_stash_entry_path(account, stash, stash_action: "add")
      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the new entry form for the owner" do
      sign_in user
      get new_account_stash_stash_entry_path(account, stash, stash_action: "add")
      expect(response).to be_successful
    end
  end

  describe "POST /accounts/:account_id/stashes/:stash_id/stash_entries (add)" do
    before { sign_in user }

    it "increments the stash balance and creates a linked locked transfer transaction" do
      expect {
        post account_stash_stash_entries_path(account, stash),
             params: { stash_entry: { stash_action: "add", amount: 250, stash_entry_date: Date.current.to_s } }
      }.to change { StashEntry.count }.by(1)
       .and change { stash.reload.balance }.by(BigDecimal("250"))

      entry = StashEntry.last
      expect(entry.amount).to eq(BigDecimal("250")) # add → positive
      expect(entry.linked_transaction).to be_present
      expect(entry.linked_transaction.locked).to be true
      expect(entry.linked_transaction.transfer).to be true
      expect(entry.linked_transaction.description).to include("Transfer to")
      expect(response).to redirect_to(account_transactions_path)
    end
  end

  describe "POST /accounts/:account_id/stashes/:stash_id/stash_entries (remove)" do
    before do
      sign_in user
      # Seed the stash with some balance so the remove validation passes.
      StashEntry.create!(stash: stash, stash_action: "add", amount: 500,
                         stash_entry_date: Date.current)
    end

    it "decrements the stash balance and stores a negative-amount entry" do
      expect {
        post account_stash_stash_entries_path(account, stash),
             params: { stash_entry: { stash_action: "remove", amount: 100, stash_entry_date: Date.current.to_s } }
      }.to change { stash.reload.balance }.by(BigDecimal("-100"))

      entry = StashEntry.last
      expect(entry.amount).to eq(BigDecimal("-100"))
      expect(entry.linked_transaction.description).to include("Transfer from")
    end
  end

  describe "validation failures" do
    before { sign_in user }

    it "re-renders the form when amount is missing" do
      post account_stash_stash_entries_path(account, stash),
           params: { stash_entry: { stash_action: "add", amount: "", stash_entry_date: Date.current.to_s } }
      expect(response).to have_http_status(:ok) # render :new
      expect(response.body).to include("can&#39;t be blank").or include("can't be blank")
    end
  end
end
