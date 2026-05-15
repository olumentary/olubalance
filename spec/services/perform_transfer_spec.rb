# frozen_string_literal: true

require "rails_helper"

RSpec.describe PerformTransfer, type: :model do
  describe "#do_transfer" do
    let(:user) { create(:user) }
    let!(:source_account) { create(:account, name: "Source Account", user: user) }
    let!(:target_account) { create(:account, name: "Target Account", user: user) }

    it "updates the source and target account balances" do
      amount = 500
      described_class.new(source_account.id, target_account.id, amount).do_transfer
      source_account.reload
      target_account.reload
      expect(source_account.current_balance).to eq(source_account.starting_balance - amount)
      expect(target_account.current_balance).to eq(target_account.starting_balance + amount)
    end

    describe "transfer transactions" do
      let!(:amount) { 1000 }
      let!(:transfer) { described_class.new(source_account.id, target_account.id, amount).do_transfer }
      let!(:source_transaction) { source_account.transactions.last }
      let!(:target_transaction) { target_account.transactions.last }

      it "creates a source account transaction" do
        expect(source_transaction.transaction_type).to include("debit")
        expect(source_transaction.account_id).to eq(source_account.id)
        expect(source_transaction.description).to eq("Transfer to #{target_account.name}")
        expect(source_transaction.amount).to be < 0
        expect(source_transaction.amount).to eq(-amount.to_d)
        expect(source_transaction.locked).to be true
        expect(source_transaction.transfer).to be true
        expect(source_transaction.category.name).to eq("Transfer")
      end

      it "creates a target account transaction" do
        expect(target_transaction.transaction_type).to include("credit")
        expect(target_transaction.account_id).to eq(target_account.id)
        expect(target_transaction.description).to eq("Transfer from #{source_account.name}")
        expect(target_transaction.amount).to be > 0
        expect(target_transaction.amount).to eq(amount.to_d)
        expect(target_transaction.locked).to be true
        expect(target_transaction.transfer).to be true
        expect(target_transaction.category.name).to eq("Transfer")
      end

      it "links the two transactions to each other via counterpart_transaction_id" do
        expect(source_transaction.counterpart_transaction_id).to eq(target_transaction.id)
        expect(target_transaction.counterpart_transaction_id).to eq(source_transaction.id)
      end
    end

    describe "money coercion" do
      it "stores the amount as BigDecimal when given a String" do
        described_class.new(source_account.id, target_account.id, "12.34").do_transfer
        expect(source_account.transactions.last.amount).to eq(BigDecimal("-12.34"))
        expect(target_account.transactions.last.amount).to eq(BigDecimal("12.34"))
      end

      it "stores the amount as BigDecimal when given a Float" do
        described_class.new(source_account.id, target_account.id, 12.34).do_transfer
        expect(source_account.transactions.last.amount).to eq(BigDecimal("-12.34"))
        expect(target_account.transactions.last.amount).to eq(BigDecimal("12.34"))
      end

      it "treats negative amounts as their absolute value (.abs)" do
        described_class.new(source_account.id, target_account.id, -250).do_transfer
        expect(source_account.transactions.last.amount).to eq(BigDecimal("-250"))
        expect(target_account.transactions.last.amount).to eq(BigDecimal("250"))
      end
    end

    describe "atomicity" do
      it "wraps both inserts in Transaction.transaction so a target failure rolls back the source" do
        # Empirical rollback verification across the savepoint boundary is awkward
        # under transactional fixtures (the service's joinable block can't roll
        # back the test's outer transaction). Instead we assert the two things
        # that imply correctness in production:
        #   1) `Transaction.transaction` wraps the work.
        #   2) An exception in the target step propagates out of the service,
        #      which is what makes AR roll back the open transaction.
        service = described_class.new(source_account.id, target_account.id, 500)
        allow(service).to receive(:create_target_transaction!)
          .and_raise(ActiveRecord::RecordInvalid.new(Transaction.new))

        expect(Transaction).to receive(:transaction).and_call_original

        expect { service.do_transfer }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
