# frozen_string_literal: true

require "rails_helper"

# Most of TransactionDecorator's date methods reach into
# User.new.decorate.h.controller.current_user.timezone, which requires a full
# controller context to test sensibly. This spec covers the methods that don't.
RSpec.describe TransactionDecorator do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user, starting_balance: BigDecimal("1000")) }

  let(:debit_trx) {
    create(:transaction, :non_pending, account: account,
                                       trx_type: "debit", amount: BigDecimal("25"),
                                       description: "Coffee shop")
  }
  let(:credit_trx) {
    create(:transaction, :non_pending, :credit_transaction, account: account,
                                                            amount: BigDecimal("100"),
                                                            description: "Refund")
  }

  describe "#debit / #credit" do
    it "shows the absolute value as currency for debits, blank for credits" do
      expect(debit_trx.decorate.debit).to eq(ActionController::Base.helpers.number_to_currency(25))
      expect(debit_trx.decorate.credit).to eq("&nbsp;")
    end

    it "shows the value as currency for credits, blank for debits" do
      expect(credit_trx.decorate.credit).to eq(ActionController::Base.helpers.number_to_currency(100))
      expect(credit_trx.decorate.debit).to eq("&nbsp;")
    end
  end

  describe "#amount_decorated" do
    it "returns 'Pending' when amount is nil" do
      pending_trx = build(:transaction, account: account, amount: nil, description: nil, pending: true)
      pending_trx.save!(validate: false)
      expect(pending_trx.decorate.amount_decorated).to eq("Pending")
    end

    it "formats with currency" do
      formatted = debit_trx.decorate.amount_decorated
      expect(formatted).to include("25")
    end
  end

  describe "#amount_color" do
    it "is has-text-grey when amount is nil" do
      pending_trx = build(:transaction, account: account, amount: nil, description: nil, pending: true)
      pending_trx.save!(validate: false)
      expect(pending_trx.decorate.amount_color).to eq("has-text-grey")
    end

    it "is has-text-danger for debits (negative amounts)" do
      expect(debit_trx.decorate.amount_color).to eq("has-text-danger")
    end

    it "is has-text-success for credits (positive amounts)" do
      expect(credit_trx.decorate.amount_color).to eq("has-text-success")
    end
  end

  describe "#trx_type_value_form" do
    it "is 'debit' for new (unsaved) records" do
      expect(build(:transaction, account: account).decorate.trx_type_value_form).to eq("debit")
    end

    it "is 'debit' when persisted amount is negative" do
      expect(debit_trx.decorate.trx_type_value_form).to eq("debit")
    end

    it "is 'credit' when persisted amount is positive" do
      expect(credit_trx.decorate.trx_type_value_form).to eq("credit")
    end
  end

  describe "#memo_decorated" do
    it "shows the memo when present" do
      expect(debit_trx.decorate.memo_decorated).to eq(debit_trx.memo)
    end

    it "shows '- None -' when blank" do
      debit_trx.update_columns(memo: "")
      expect(debit_trx.reload.decorate.memo_decorated).to eq("- None -")
    end
  end

  describe "description-truncation helpers" do
    it "trims to 50 chars with ellipsis for long descriptions" do
      long = "A" * 100
      debit_trx.update!(description: long, trx_type: "debit")
      decorated = debit_trx.reload.decorate
      expect(decorated.name_too_long).to be true
      expect(decorated.trx_desc_display).to end_with("...")
    end

    it "returns 'Pending Receipt' when description is nil" do
      pending_trx = build(:transaction, account: account, amount: nil, description: nil, pending: true)
      pending_trx.save!(validate: false)
      expect(pending_trx.decorate.trx_desc_display).to eq("Pending Receipt")
    end
  end

  describe "#button_label" do
    it "is 'Create Transaction' for new records" do
      expect(build(:transaction, account: account).decorate.button_label).to eq("Create Transaction")
    end

    it "is 'Update Transaction' for persisted records" do
      expect(debit_trx.decorate.button_label).to eq("Update Transaction")
    end
  end

  describe "#running_balance_display" do
    it "formats the view-backed running_balance as currency" do
      formatted = debit_trx.decorate.running_balance_display
      expect(formatted).to start_with("$").or start_with("-$")
    end
  end

  describe "#transfer_type" do
    it "is nil for non-transfer transactions" do
      expect(debit_trx.decorate.transfer_type).to be_nil
    end

    it "is 'account_to_account' for a counterpart-linked transfer" do
      target = create(:account, user: user)
      PerformTransfer.new(account.id, target.id, 50).do_transfer
      debit = account.transactions.where(transfer: true).order(:id).last
      expect(debit.decorate.transfer_type).to eq("account_to_account")
    end
  end
end
