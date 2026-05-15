# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Transactions::Batches", type: :request do
  let(:user)     { create(:user) }
  let(:account)  { create(:account, user: user) }
  let(:category) { create(:category, :global) }
  let!(:bill)    {
    create(:bill, user: user, account: account, category: category,
                  amount: BigDecimal("100"), day_of_month: 15, description: "Rent")
  }

  describe "authentication" do
    it "redirects to login on index when not signed in" do
      get transactions_batches_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects to login on create when not signed in" do
      post transactions_batches_path, params: { month: "2026-04" }
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /transactions/batches" do
    before { sign_in user }

    it "renders the index with the current user's batches" do
      create(:bill_transaction_batch, user: user, period_month: Date.new(2026, 4, 1))
      get transactions_batches_path
      expect(response).to be_successful
    end
  end

  describe "GET /transactions/batches/new (preview)" do
    before { sign_in user }

    it "renders preview items for the requested month" do
      get new_transactions_batch_path(month: "2026-04")
      expect(response).to be_successful
      expect(response.body).to include("Rent")
    end
  end

  describe "POST /transactions/batches (create)" do
    before { sign_in user }

    it "generates a batch, sets a success flash, and redirects to bills" do
      expect {
        post transactions_batches_path, params: { start_date: "2026-04-01", end_date: "2026-04-30" }
      }.to change { BillTransactionBatch.count }.by(1)
       .and change { Transaction.count }.by(1)

      expect(response).to redirect_to(bills_path(view: nil))
      expect(flash[:notice]).to include("1 pending transactions generated")
      expect(flash[:undo_batch_id]).to eq(BillTransactionBatch.last.id)
    end

    it "sets an alert and creates nothing when there are no items in range" do
      # Use a range where no monthly-on-15th bill triggers (1st–10th of the month).
      expect {
        post transactions_batches_path, params: { start_date: "2026-04-01", end_date: "2026-04-10" }
      }.not_to change { BillTransactionBatch.count }

      expect(flash[:alert]).to include("No pending transactions were generated")
    end
  end

  describe "DELETE /transactions/batches/:id (undo)" do
    before { sign_in user }

    let!(:batch_result) {
      described_class = BillTransactions::Generator
      described_class.new(user: user).generate!(start_date: Date.new(2026, 4, 1), end_date: Date.new(2026, 4, 30))
    }
    let(:batch) { batch_result.batch }

    it "destroys the batch and all of its (pending) transactions atomically" do
      expect(batch).to be_present
      expect(batch.transactions.count).to eq(1)

      expect {
        delete transactions_batch_path(batch), headers: { "HTTP_REFERER" => bills_url }
      }.to change { BillTransactionBatch.count }.by(-1)
       .and change { Transaction.count }.by(-1)

      expect(flash[:notice]).to include("undone")
    end

    it "refuses to undo when any child transaction has been reviewed" do
      # Mark the child non-pending (i.e. approved/reviewed).
      child = batch.transactions.first
      child.update!(pending: false, trx_type: "debit")

      expect {
        delete transactions_batch_path(batch), headers: { "HTTP_REFERER" => bills_url }
      }.not_to change { BillTransactionBatch.count }

      expect(flash[:alert]).to include("Cannot undo")
    end
  end

  describe "cross-user access (IDOR)" do
    let(:attacker) { create(:user) }
    let!(:attacker_batch) { create(:bill_transaction_batch, user: attacker, period_month: Date.new(2026, 4, 1)) }

    it "returns 404 when the signed-in user tries to view someone else's batch" do
      sign_in user
      get transactions_batch_path(attacker_batch)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when the signed-in user tries to destroy someone else's batch" do
      sign_in user
      expect {
        delete transactions_batch_path(attacker_batch)
      }.not_to change { BillTransactionBatch.count }
      expect(response).to have_http_status(:not_found)
    end
  end
end
