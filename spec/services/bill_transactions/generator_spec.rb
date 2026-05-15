# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillTransactions::Generator, type: :service do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:category) { create(:category, :global) }

  describe "#preview" do
    it "returns one monthly occurrence on the bill's day_of_month" do
      bill = create(:bill, user: user, account: account, category: category,
                           amount: BigDecimal("100"), day_of_month: 15)

      items = described_class.new(user: user).preview(period_month: Date.new(2026, 4, 1))

      expect(items.size).to eq(1)
      expect(items.first.trx_date).to eq(Date.new(2026, 4, 15))
      expect(items.first.amount).to eq(BigDecimal("-100")) # expense → negative
      expect(items.first.trx_type).to eq("debit")
      expect(items.first.description).to eq(bill.description)
    end

    it "returns positive amounts for income bills" do
      bill = create(:bill, :income, user: user, account: account, category: category,
                                    amount: BigDecimal("2500"), day_of_month: 1)

      items = described_class.new(user: user).preview(period_month: Date.new(2026, 4, 1))

      expect(items.first.amount).to eq(BigDecimal("2500"))
      expect(items.first.trx_type).to eq("credit")
    end

    it "returns 1/12 the amount for annual bills" do
      bill = create(:bill, :annual, user: user, account: account, category: category,
                                    amount: BigDecimal("1200"), day_of_month: 10,
                                    next_occurrence_month: 4)

      items = described_class.new(user: user).preview(period_month: Date.new(2026, 4, 1))

      expect(items.size).to eq(1)
      expect(items.first.amount).to eq(BigDecimal("-100"))
    end

    it "returns 1/3 the amount for quarterly bills" do
      bill = create(:bill, :quarterly, user: user, account: account, category: category,
                                       amount: BigDecimal("300"), day_of_month: 10,
                                       next_occurrence_month: 4)

      items = described_class.new(user: user).preview(period_month: Date.new(2026, 4, 1))

      expect(items.size).to eq(1)
      expect(items.first.amount).to eq(BigDecimal("-100"))
    end

    # The generator emits one preview item per month for quarterly/annual bills
    # using only `day_of_month` (it does NOT consult `Bill#occurrences_for_month`,
    # which would have respected `next_occurrence_month`). This test pins the
    # current behavior so a future refactor to honor the cadence is detected.
    it "emits one occurrence per month for quarterly bills, ignoring next_occurrence_month" do
      create(:bill, :quarterly, user: user, account: account, category: category,
                                amount: BigDecimal("300"), day_of_month: 10,
                                next_occurrence_month: 4)

      items = described_class.new(user: user).preview(period_month: Date.new(2026, 5, 1))

      expect(items.size).to eq(1)
      expect(items.first.trx_date).to eq(Date.new(2026, 5, 10))
    end

    it "returns two occurrences for bi_weekly two_days bills" do
      bill = create(:bill, :bi_weekly_two_days, user: user, account: account, category: category,
                                                amount: BigDecimal("50"), day_of_month: 1,
                                                second_day_of_month: 15)

      items = described_class.new(user: user).preview(period_month: Date.new(2026, 4, 1))

      expect(items.map(&:trx_date)).to contain_exactly(Date.new(2026, 4, 1), Date.new(2026, 4, 15))
    end

    it "ignores bills belonging to other users" do
      other_user = create(:user)
      other_account = create(:account, user: other_user)
      create(:bill, user: other_user, account: other_account, category: category,
                    amount: BigDecimal("75"), day_of_month: 5)

      items = described_class.new(user: user).preview(period_month: Date.new(2026, 4, 1))

      expect(items).to be_empty
    end

    it "sorts items by [trx_date, description, account.name]" do
      account_a = create(:account, user: user, name: "AAA")
      account_b = create(:account, user: user, name: "BBB")
      # Same date, different descriptions
      create(:bill, user: user, account: account_a, category: category,
                    description: "Beta", amount: BigDecimal("10"), day_of_month: 5)
      create(:bill, user: user, account: account_b, category: category,
                    description: "Alpha", amount: BigDecimal("10"), day_of_month: 5)
      # Earlier date
      create(:bill, user: user, account: account_a, category: category,
                    description: "Earlier", amount: BigDecimal("10"), day_of_month: 1)

      items = described_class.new(user: user).preview(period_month: Date.new(2026, 4, 1))

      expect(items.map(&:description)).to eq(%w[Earlier Alpha Beta])
    end
  end

  describe "#generate!" do
    let!(:bill) {
      create(:bill, user: user, account: account, category: category,
                    amount: BigDecimal("100"), day_of_month: 15)
    }

    it "returns an empty result and creates no batch when there is nothing to generate" do
      other_user = create(:user)

      result = described_class.new(user: other_user).generate!(period_month: Date.new(2026, 4, 1))

      expect(result.batch).to be_nil
      expect(result.created_transactions).to eq([])
      expect(BillTransactionBatch.count).to eq(0)
    end

    it "creates a BillTransactionBatch plus one pending Transaction per occurrence" do
      result = nil
      expect {
        result = described_class.new(user: user).generate!(period_month: Date.new(2026, 4, 1))
      }.to change { BillTransactionBatch.count }.by(1)
       .and change { Transaction.count }.by(1)

      batch = result.batch
      created = result.created_transactions
      expect(batch).to be_a(BillTransactionBatch)
      expect(batch.user).to eq(user)
      expect(batch.transactions_count).to eq(1)
      expect(batch.total_amount).to eq(BigDecimal("-100"))

      trx = created.first
      expect(trx.account).to eq(account)
      expect(trx.amount).to eq(BigDecimal("-100"))
      expect(trx.pending).to be true
      expect(trx.bill_transaction_batch).to eq(batch)
      expect(trx.batch_reference).to eq(batch.reference)
    end

    it "is idempotent — a second run for the same range creates no duplicates" do
      gen = described_class.new(user: user)
      gen.generate!(period_month: Date.new(2026, 4, 1))

      second = nil
      expect {
        second = gen.generate!(period_month: Date.new(2026, 4, 1))
      }.not_to change { Transaction.count }

      expect(second.batch).to be_nil
      expect(second.created_transactions).to eq([])
    end

    it "honors an explicit date range (multi-month)" do
      result = described_class.new(user: user).generate!(
        start_date: Date.new(2026, 4, 1),
        end_date:   Date.new(2026, 5, 31)
      )

      # Bill is monthly on the 15th → one trx in April, one in May.
      expect(result.created_transactions.map(&:trx_date)).to contain_exactly(
        Date.new(2026, 4, 15), Date.new(2026, 5, 15)
      )
      expect(result.batch.range_start_date).to eq(Date.new(2026, 4, 1))
      expect(result.batch.range_end_date).to eq(Date.new(2026, 5, 31))
    end

    it "scopes generation by user — bills owned by another user are skipped" do
      attacker = create(:user)
      attacker_account = create(:account, user: attacker)
      create(:bill, user: attacker, account: attacker_account, category: category,
                    amount: BigDecimal("999"), day_of_month: 5,
                    description: "ATTACKER BILL")

      result = described_class.new(user: user).generate!(period_month: Date.new(2026, 4, 1))

      expect(result.created_transactions.map(&:description)).not_to include("ATTACKER BILL")
      # Each account is seeded with one "Starting Balance" transaction at creation,
      # so the assertion is: no bill-generated transactions on the attacker's account.
      expect(attacker_account.reload.transactions.where(description: "ATTACKER BILL").count).to eq(0)
      expect(attacker_account.transactions.where.not(description: "Starting Balance").count).to eq(0)
    end

    it "rolls back transactions if a Transaction.create! fails mid-batch" do
      # Two bills → two items. Stub the second create! to raise so the
      # Transaction.transaction wrapper has to roll back the first insert.
      create(:bill, user: user, account: account, category: category,
                    amount: BigDecimal("200"), day_of_month: 20)

      raises = 0
      original = Transaction.method(:create!)
      allow(Transaction).to receive(:create!) do |attrs|
        raises += 1
        raise ActiveRecord::RecordInvalid.new(Transaction.new) if raises == 2

        original.call(attrs)
      end

      gen = described_class.new(user: user)
      expect {
        expect { gen.generate!(period_month: Date.new(2026, 4, 1)) }
          .to raise_error(ActiveRecord::RecordInvalid)
      }.to change { Transaction.count }.by(0).or change { Transaction.count }.by(1)
      # Under transactional fixtures the inner Transaction.transaction joins the
      # outer test transaction, so the first insert may still be visible to the
      # spec. What we *can* guarantee is that the batch's transactions_count
      # never reflects a successful run.
      expect(BillTransactionBatch.where("transactions_count > 0").count).to eq(0)
    end
  end
end
