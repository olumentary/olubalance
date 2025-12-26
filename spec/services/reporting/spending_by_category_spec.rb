# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reporting::SpendingByCategory do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:category1) { create(:category, user: user, name: "Groceries") }
  let(:category2) { create(:category, user: user, name: "Entertainment") }

  describe "#call" do
    subject(:result) { described_class.new(user: user, **options).call }

    let(:options) { {} }

    context "with no transactions" do
      it "returns empty categories" do
        expect(result[:categories]).to be_empty
      end

      it "returns zero totals" do
        expect(result[:totals][:current]).to eq(0)
        expect(result[:totals][:previous]).to eq(0)
      end
    end

    context "with spending transactions in current period" do
      before do
        create(:transaction, :non_pending, account: account, category: category1,
               amount: -100, trx_date: Date.current, trx_type: "debit", pending: false,
               description: "Grocery Store Purchase")
        create(:transaction, :non_pending, account: account, category: category2,
               amount: -50, trx_date: Date.current, trx_type: "debit", pending: false,
               description: "Movie Tickets")
      end

      it "returns categories with spending" do
        expect(result[:categories]).to contain_exactly("Entertainment", "Groceries")
      end

      it "returns current period data" do
        groceries_index = result[:categories].index("Groceries")
        entertainment_index = result[:categories].index("Entertainment")

        expect(result[:current_period][:data][groceries_index]).to eq(100)
        expect(result[:current_period][:data][entertainment_index]).to eq(50)
      end

      it "returns current total" do
        expect(result[:totals][:current]).to eq(150)
      end
    end

    context "with spending in both current and previous periods" do
      before do
        # Current period
        create(:transaction, :non_pending, account: account, category: category1,
               amount: -120, trx_date: Date.current, trx_type: "debit", pending: false)

        # Previous period (last month)
        create(:transaction, :non_pending, account: account, category: category1,
               amount: -100, trx_date: Date.current.beginning_of_month - 10.days, trx_type: "debit", pending: false)
      end

      it "returns spending for both periods" do
        expect(result[:totals][:current]).to eq(120)
        expect(result[:totals][:previous]).to eq(100)
      end

      it "calculates difference" do
        expect(result[:totals][:difference]).to eq(20)
      end

      it "calculates percentage change" do
        expect(result[:totals][:percentage_change]).to eq(20.0)
      end
    end

    context "with uncategorized transactions" do
      before do
        create(:transaction, :non_pending, account: account, category: nil,
               amount: -75, trx_date: Date.current, trx_type: "debit", pending: false)
      end

      it "groups under Uncategorized" do
        expect(result[:categories]).to include("Uncategorized")
      end
    end

    context "with date range filter" do
      let(:options) do
        {
          start_date: Date.current - 7.days,
          end_date: Date.current
        }
      end

      before do
        # Within range
        create(:transaction, :non_pending, account: account, category: category1,
               amount: -50, trx_date: Date.current - 3.days, trx_type: "debit", pending: false)

        # Outside range
        create(:transaction, :non_pending, account: account, category: category1,
               amount: -100, trx_date: Date.current - 30.days, trx_type: "debit", pending: false)
      end

      it "only includes transactions within range" do
        expect(result[:totals][:current]).to eq(50)
      end
    end

    context "with category filter" do
      let(:options) { { category_ids: [category1.id] } }

      before do
        create(:transaction, :non_pending, account: account, category: category1,
               amount: -100, trx_date: Date.current, trx_type: "debit", pending: false,
               description: "Grocery Store")
        create(:transaction, :non_pending, account: account, category: category2,
               amount: -50, trx_date: Date.current, trx_type: "debit", pending: false,
               description: "Movie Theater")
      end

      it "only includes filtered categories" do
        expect(result[:categories]).to eq(["Groceries"])
        expect(result[:totals][:current]).to eq(100)
      end
    end

    context "with account filter" do
      let(:other_account) { create(:account, user: user) }
      let(:options) { { account_ids: [account.id] } }

      before do
        create(:transaction, :non_pending, account: account, category: category1,
               amount: -100, trx_date: Date.current, trx_type: "debit", pending: false,
               description: "Main Account Purchase")
        create(:transaction, :non_pending, account: other_account, category: category1,
               amount: -50, trx_date: Date.current, trx_type: "debit", pending: false,
               description: "Other Account Purchase")
      end

      it "only includes transactions from filtered account" do
        expect(result[:totals][:current]).to eq(100)
      end
    end

    context "ignoring credit transactions" do
      before do
        create(:transaction, :non_pending, account: account, category: category1,
               amount: -100, trx_date: Date.current, trx_type: "debit", pending: false,
               description: "Debit Purchase")
        create(:transaction, :non_pending, :credit_transaction, account: account, category: category1,
               amount: 200, trx_date: Date.current, pending: false,
               description: "Credit Refund")
      end

      it "only includes debit (spending) transactions" do
        expect(result[:totals][:current]).to eq(100)
      end
    end

    context "ignoring pending transactions" do
      before do
        create(:transaction, :non_pending, account: account, category: category1,
               amount: -100, trx_date: Date.current, trx_type: "debit", pending: false,
               description: "Reviewed Purchase")
        # Pending transaction
        create(:transaction, account: account, category: category1,
               amount: -50, trx_date: Date.current, trx_type: "debit", pending: true,
               description: "Pending Purchase")
      end

      it "only includes non-pending transactions" do
        expect(result[:totals][:current]).to eq(100)
      end
    end

    context "ignoring inactive accounts" do
      let(:inactive_account) { create(:account, user: user, active: false) }

      before do
        create(:transaction, :non_pending, account: account, category: category1,
               amount: -100, trx_date: Date.current, trx_type: "debit", pending: false,
               description: "Active Account Purchase")
        create(:transaction, :non_pending, account: inactive_account, category: category1,
               amount: -50, trx_date: Date.current, trx_type: "debit", pending: false,
               description: "Inactive Account Purchase")
      end

      it "excludes transactions from inactive accounts" do
        expect(result[:totals][:current]).to eq(100)
      end
    end
  end
end

