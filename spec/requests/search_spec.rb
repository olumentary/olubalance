require "rails_helper"

RSpec.describe "Search", type: :request do
  let(:user)     { create(:user) }
  let(:account)  { create(:account, user: user) }
  let!(:lunch)   {
    create(:transaction, :non_pending, account: account, description: "Lunch at diner",
                                       trx_type: "debit", amount: BigDecimal("12"))
  }
  let!(:gas)     {
    create(:transaction, :non_pending, account: account, description: "Gas station",
                                       trx_type: "debit", amount: BigDecimal("40"))
  }

  describe "GET /search" do
    it "redirects to login when not signed in" do
      get search_index_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders all of the user's transactions when no query is supplied" do
      sign_in user
      get search_index_path
      expect(response).to be_successful
      expect(response.body).to include("Lunch at diner")
      expect(response.body).to include("Gas station")
    end

    it "filters by description query (case-insensitive)" do
      sign_in user
      get search_index_path, params: { query: "lunch" }
      expect(response).to be_successful
      expect(response.body).to include("Lunch at diner")
      expect(response.body).not_to include("Gas station")
    end

    it "does not return another user's transactions even when the description matches" do
      other_user = create(:user)
      other_account = create(:account, user: other_user)
      create(:transaction, :non_pending, account: other_account, description: "Lunch at OTHER place")

      sign_in user
      get search_index_path, params: { query: "Lunch" }
      expect(response.body).not_to include("OTHER place")
    end

    it "applies the account filter" do
      other_account = create(:account, user: user, name: "Second")
      create(:transaction, :non_pending, account: other_account, description: "Gym")

      sign_in user
      get search_index_path, params: { account_id: other_account.id }
      expect(response.body).to include("Gym")
      expect(response.body).not_to include("Lunch at diner")
    end
  end
end
