require "rails_helper"

RSpec.describe "Quick transactions", type: :request do
  let(:user)    { create(:user) }
  let!(:account) { create(:account, user: user) }
  let(:fixture_image) {
    Rack::Test::UploadedFile.new(Rails.root.join("app/assets/images/logo.png"), "image/png")
  }

  describe "GET /quick_transactions/new" do
    it "redirects to login when not signed in" do
      get new_quick_transaction_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the new form for the signed-in user" do
      sign_in user
      get new_quick_transaction_path
      expect(response).to be_successful
    end

    it "pre-selects the user's default account when one is set" do
      user.update!(default_account_id: account.id)
      sign_in user
      get new_quick_transaction_path
      expect(response).to be_successful
      expect(response.body).to include(account.name)
    end
  end

  describe "POST /quick_transactions" do
    before { sign_in user }

    it "creates a pending quick_receipt transaction with the attached file" do
      expect {
        post quick_transactions_path, params: {
          transaction: { account_id: account.id, attachments: [ fixture_image ] }
        }
      }.to change { Transaction.where(quick_receipt: true).count }.by(1)

      trx = Transaction.where(quick_receipt: true).last
      expect(trx.pending).to be true
      expect(trx.account_id).to eq(account.id)
      expect(trx.attachments.attached?).to be true
      expect(response).to redirect_to(account_transactions_path(account))
      expect(flash[:notice]).to include("Receipt uploaded successfully")
    end

    it "re-renders the new form when no attachment is provided" do
      post quick_transactions_path, params: { transaction: { account_id: account.id } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
