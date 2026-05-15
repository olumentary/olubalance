require "rails_helper"

RSpec.describe "Summary", type: :request do
  let(:user) { create(:user) }
  let!(:checking) { create(:account, :checking, user: user, starting_balance: BigDecimal("1000")) }
  let!(:savings)  { create(:account, :savings,  user: user, starting_balance: BigDecimal("500")) }

  describe "GET /accounts/summary" do
    it "redirects to login when not signed in" do
      get "/accounts/summary"
      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the summary for the signed-in user" do
      sign_in user
      get "/accounts/summary"
      expect(response).to be_successful
      expect(response.body).to include(checking.name)
      expect(response.body).to include(savings.name)
    end

    it "does not include another user's accounts" do
      other_user = create(:user)
      other_account = create(:account, user: other_user, name: "OUTSIDER")
      sign_in user
      get "/accounts/summary"
      expect(response.body).not_to include("OUTSIDER")
    end
  end

  describe "POST /accounts/summary/mail" do
    before { ActionMailer::Base.deliveries.clear }

    it "queues a SummaryMailer email to the requested recipient" do
      sign_in user
      expect {
        post "/accounts/summary/mail", params: { summary_mail: { to: "to@example.com" } }
      }.to change { ActionMailer::Base.deliveries.size }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to include("to@example.com")
    end
  end
end
