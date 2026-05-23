# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reconcile (Weekly catch-up)", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before { sign_in user }

  describe "GET /reconcile" do
    it "renders successfully with no accounts" do
      get reconcile_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Weekly catch-up")
    end

    it "lists only accounts not yet reviewed this week" do
      reviewed = create(:account, user: user, name: "Reviewed")
      pending = create(:account, user: user, name: "Pending")
      reviewed.update_columns(last_transaction_on: Date.current)
      pending.update_columns(last_transaction_on: 30.days.ago.to_date)

      get reconcile_path
      expect(response.body).to include("Pending")
      expect(response.body).not_to include("Reviewed</p>")
    end
  end

  describe "POST /reconcile/mark_current" do
    let!(:pending_account) do
      a = create(:account, user: user)
      a.update_columns(last_transaction_on: 30.days.ago.to_date)
      a
    end

    it "stamps the account's last_transaction_on to today" do
      post mark_current_reconcile_path, params: { account_id: pending_account.id }
      expect(pending_account.reload.last_transaction_on).to eq(Date.current)
    end

    it "is scoped to current_user — cannot mark another user's account" do
      foreign = create(:account, user: other_user)
      foreign.update_columns(last_transaction_on: 30.days.ago.to_date)
      post mark_current_reconcile_path, params: { account_id: foreign.id }
      expect(response).to have_http_status(:not_found)
      expect(foreign.reload.last_transaction_on).to eq(30.days.ago.to_date)
    end

    it "responds with a turbo_stream when requested" do
      post mark_current_reconcile_path,
           params: { account_id: pending_account.id },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end
  end
end
