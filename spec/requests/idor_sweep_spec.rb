# frozen_string_literal: true

require "rails_helper"

# Per CLAUDE.md, every controller must scope through `current_user` — that's the
# IDOR boundary. Existing request specs cover GET-side scoping well; this file
# fills the gap on mutating routes (POST/PATCH/DELETE). One example per route.
RSpec.describe "Cross-user IDOR protection on mutating routes", type: :request do
  let(:user)        { create(:user) }
  let(:user_account) { create(:account, user: user) }
  let(:victim)      { create(:user) }
  let(:victim_account) { create(:account, user: victim) }

  before { sign_in user }

  describe "Transactions" do
    let!(:victim_transaction) {
      create(:transaction, :non_pending, account: victim_account, description: "VICTIM TXN")
    }

    it "returns 404 on PATCH /accounts/:account_id/transactions/:id for another user's transaction" do
      patch account_transaction_path(victim_account, victim_transaction),
            params: { transaction: { description: "OWNED" } }
      expect(response).to have_http_status(:not_found)
      expect(victim_transaction.reload.description).to eq("VICTIM TXN")
    end

    it "returns 404 on DELETE /accounts/:account_id/transactions/:id for another user's transaction" do
      expect {
        delete account_transaction_path(victim_account, victim_transaction)
      }.not_to change { Transaction.where(id: victim_transaction.id).count }
      expect(response).to have_http_status(:not_found)
    end

    it "rejects PATCH /mark_reviewed for another user's transaction" do
      # Seed the victim row as pending so flipping it would be a visible change.
      victim_transaction.update_columns(pending: true)
      patch mark_reviewed_account_transaction_path(user_account, victim_transaction),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:not_found)
      expect(victim_transaction.reload.pending).to be true
    end

    it "rejects PATCH /mark_pending for another user's transaction" do
      victim_transaction.update_columns(pending: false)
      patch mark_pending_account_transaction_path(user_account, victim_transaction),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:not_found)
      expect(victim_transaction.reload.pending).to be false
    end
  end

  describe "Stashes" do
    let!(:victim_stash) { create(:stash, account: victim_account) }

    it "returns 404 on PATCH /accounts/:account_id/stashes/:id for another user's stash" do
      patch account_stash_path(victim_account, victim_stash),
            params: { stash: { name: "OWNED" } }
      expect(response).to have_http_status(:not_found)
      expect(victim_stash.reload.name).not_to eq("OWNED")
    end

    it "returns 404 on DELETE /accounts/:account_id/stashes/:id for another user's stash" do
      expect {
        delete account_stash_path(victim_account, victim_stash)
      }.not_to change { Stash.where(id: victim_stash.id).count }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "Stash entries" do
    let!(:victim_stash) { create(:stash, account: victim_account) }

    it "rejects POST /accounts/:account_id/stashes/:stash_id/stash_entries on another user's stash" do
      expect {
        post account_stash_stash_entries_path(victim_account, victim_stash),
             params: { stash_entry: { stash_action: "add", amount: 10, stash_entry_date: Date.current.to_s } }
      }.not_to change { StashEntry.count }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "Matching rules" do
    let!(:victim_rule) {
      create(:category_lookup, user: victim, description_norm: "victim rule",
                               category: create(:category, :global))
    }

    it "returns 404 on PATCH /matching_rules/:id for another user's rule" do
      patch matching_rule_path(victim_rule),
            params: { matching_rule: { description_norm: "owned rule" } }
      expect(response).to have_http_status(:not_found)
      expect(victim_rule.reload.description_norm).to eq("victim rule")
    end

    it "returns 404 on DELETE /matching_rules/:id for another user's rule" do
      expect {
        delete matching_rule_path(victim_rule)
      }.not_to change { CategoryLookup.where(id: victim_rule.id).count }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "Bills" do
    let!(:victim_bill) {
      create(:bill, user: victim, account: victim_account,
                    category: create(:category, :global), description: "VICTIM BILL")
    }

    it "returns 404 on PATCH /bills/:id for another user's bill" do
      patch bill_path(victim_bill), params: { bill: { description: "OWNED" } }
      expect(response).to have_http_status(:not_found)
      expect(victim_bill.reload.description).to eq("VICTIM BILL")
    end

    it "returns 404 on DELETE /bills/:id for another user's bill" do
      expect {
        delete bill_path(victim_bill)
      }.not_to change { Bill.where(id: victim_bill.id).count }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "Documents" do
    let!(:victim_document) { create(:user_document, attachable: victim) }

    it "redirects with 'access denied' on PATCH /documents/:id for another user's document" do
      patch document_path(victim_document),
            params: { document: { level: "User", description: "OWNED" } }
      # The controller rescues RecordNotFound and redirects with an alert (see
      # documents_controller.rb:130-132), so we assert that path rather than 404.
      expect(response).to redirect_to(documents_path)
      expect(flash[:alert]).to include("access denied").or include("not found")
    end
  end
end
