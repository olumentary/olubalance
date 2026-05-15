# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionsHelper, type: :helper do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:pending_trx) { create(:transaction, account: account, description: "x", trx_type: "debit", amount: 5) }
  let(:reviewed_trx) {
    create(:transaction, :non_pending, account: account, trx_type: "debit", amount: BigDecimal("9.5"), description: "y")
  }

  describe "#formatted_amount_value" do
    it "returns 2-decimal absolute string for a present amount" do
      expect(helper.formatted_amount_value(reviewed_trx)).to eq("9.50")
    end

    it "returns empty when amount is nil" do
      blank = build(:transaction, account: account, amount: nil, description: nil, pending: true)
      blank.save!(validate: false)
      expect(helper.formatted_amount_value(blank)).to eq("")
    end
  end

  describe "#cell_style / #clickable_class" do
    it "returns cursor and is-clickable for pending transactions" do
      expect(helper.cell_style(pending_trx)).to eq("cursor: pointer;")
      expect(helper.clickable_class(pending_trx)).to eq("is-clickable")
    end

    it "returns empty for non-pending transactions" do
      expect(helper.cell_style(reviewed_trx)).to eq("")
      expect(helper.clickable_class(reviewed_trx)).to eq("")
    end
  end

  describe "#bill_generated?" do
    it "is false for ordinary transactions" do
      expect(helper.bill_generated?(reviewed_trx)).to be false
    end

    it "is true when a batch is attached" do
      batch = create(:bill_transaction_batch, user: user)
      reviewed_trx.update!(bill_transaction_batch: batch)
      expect(helper.bill_generated?(reviewed_trx.reload)).to be true
    end

    it "is true when only batch_reference is set" do
      reviewed_trx.update_columns(batch_reference: SecureRandom.uuid)
      expect(helper.bill_generated?(reviewed_trx.reload)).to be true
    end
  end

  describe "#bill_generated_icon" do
    it "returns empty string when transaction is not bill-generated" do
      expect(helper.bill_generated_icon(reviewed_trx)).to eq("")
    end

    it "returns a wrapped <i> icon when bill-generated" do
      reviewed_trx.update_columns(batch_reference: SecureRandom.uuid)
      html = helper.bill_generated_icon(reviewed_trx.reload)
      expect(html).to include("fa-magic")
      expect(html).to include("Generated from bill")
    end
  end

  describe "#inline_edit_attributes" do
    it "returns an empty hash for non-pending transactions" do
      expect(helper.inline_edit_attributes(reviewed_trx, :description, "x")).to eq({})
    end

    it "returns a stimulus-wired hash for pending transactions" do
      # inline_edit_attributes calls account_transaction_path(id:), but the
      # route is nested under :account_id. In a real request that param comes
      # from params; in a helper spec we have to fake it.
      allow(helper).to receive(:account_transaction_path).and_return("/accounts/1/transactions/#{pending_trx.id}")
      attrs = helper.inline_edit_attributes(pending_trx, :description, "x")
      expect(attrs[:controller]).to eq("inline-edit")
      expect(attrs[:"inline-edit-field-value"]).to eq(:description)
      expect(attrs[:action]).to eq("click->inline-edit#showInput")
    end
  end

  describe "#inline_edit_input_attributes" do
    it "returns nil for non-pending transactions" do
      expect(helper.inline_edit_input_attributes(reviewed_trx, "text", "x")).to be_nil
    end

    it "merges in extra options" do
      attrs = helper.inline_edit_input_attributes(pending_trx, "number", 10, step: "0.01")
      expect(attrs[:type]).to eq("number")
      expect(attrs[:step]).to eq("0.01")
    end
  end
end
