# frozen_string_literal: true

require "rails_helper"

# Guards the Postgres VIEW defined in db/structure.sql:
#   SUM(amount) OVER (PARTITION BY account_id ORDER BY pending, trx_date, id)
# A schema migration that reorders that window or drops an indexed column
# silently corrupts running balances, which is the worst kind of bug in this app.
RSpec.describe TransactionBalance, type: :model do
  let(:account) { create(:account, starting_balance: BigDecimal("0")) }

  # Create a non-pending transaction with an exact amount + date, bypassing
  # the random Faker amount the factory normally supplies.
  def make_trx(account, amount:, trx_date:, pending: false)
    trx_type = amount.to_d.negative? ? "debit" : "credit"
    create(
      :transaction,
      :non_pending,
      account: account,
      trx_date: trx_date,
      amount: amount.to_d.abs,
      trx_type: trx_type,
      pending: pending
    )
  end

  def running_balance_for(transaction)
    TransactionBalance.find(transaction.id).running_balance
  end

  describe "running_balance per row" do
    it "matches the cumulative SUM(amount) in (pending, trx_date, id) order" do
      t1 = make_trx(account, amount: BigDecimal("100"),  trx_date: Date.new(2026, 1, 1))
      t2 = make_trx(account, amount: BigDecimal("-25"),  trx_date: Date.new(2026, 1, 2))
      t3 = make_trx(account, amount: BigDecimal("50"),   trx_date: Date.new(2026, 1, 3))

      expect(running_balance_for(t1)).to eq(BigDecimal("100"))
      expect(running_balance_for(t2)).to eq(BigDecimal("75"))
      expect(running_balance_for(t3)).to eq(BigDecimal("125"))
    end

    it "orders ties on trx_date by id" do
      same_day = Date.new(2026, 2, 1)
      t1 = make_trx(account, amount: BigDecimal("10"), trx_date: same_day)
      t2 = make_trx(account, amount: BigDecimal("20"), trx_date: same_day)
      t3 = make_trx(account, amount: BigDecimal("30"), trx_date: same_day)

      expect(running_balance_for(t1)).to eq(BigDecimal("10"))
      expect(running_balance_for(t2)).to eq(BigDecimal("30"))
      expect(running_balance_for(t3)).to eq(BigDecimal("60"))
    end

    it "places pending rows after non-pending rows in the window order" do
      reviewed = make_trx(account, amount: BigDecimal("100"), trx_date: Date.new(2026, 3, 1), pending: false)
      pending  = make_trx(account, amount: BigDecimal("40"),  trx_date: Date.new(2026, 2, 1), pending: true)

      # Even though `pending` has an earlier trx_date, the PARTITION orders on
      # `pending` first, so `reviewed` is treated as the earlier row.
      expect(running_balance_for(reviewed)).to eq(BigDecimal("100"))
      expect(running_balance_for(pending)).to  eq(BigDecimal("140"))
    end
  end

  describe "partition by account_id" do
    let(:other_account) { create(:account, user: account.user, starting_balance: BigDecimal("0")) }

    it "computes balances independently per account" do
      a_t1 = make_trx(account, amount: BigDecimal("100"), trx_date: Date.new(2026, 1, 1))
      b_t1 = make_trx(other_account, amount: BigDecimal("500"), trx_date: Date.new(2026, 1, 1))
      a_t2 = make_trx(account, amount: BigDecimal("-30"), trx_date: Date.new(2026, 1, 2))
      b_t2 = make_trx(other_account, amount: BigDecimal("-100"), trx_date: Date.new(2026, 1, 2))

      expect(running_balance_for(a_t1)).to eq(BigDecimal("100"))
      expect(running_balance_for(a_t2)).to eq(BigDecimal("70"))
      expect(running_balance_for(b_t1)).to eq(BigDecimal("500"))
      expect(running_balance_for(b_t2)).to eq(BigDecimal("400"))
    end
  end

  describe "recomputation on mutation" do
    it "recomputes when amount changes" do
      t1 = make_trx(account, amount: BigDecimal("100"), trx_date: Date.new(2026, 4, 1))
      t2 = make_trx(account, amount: BigDecimal("50"),  trx_date: Date.new(2026, 4, 2))

      t1.update!(amount: BigDecimal("200"), trx_type: "credit")

      expect(running_balance_for(t1)).to eq(BigDecimal("200"))
      expect(running_balance_for(t2)).to eq(BigDecimal("250"))
    end

    it "recomputes when trx_date changes (reordering)" do
      t1 = make_trx(account, amount: BigDecimal("100"), trx_date: Date.new(2026, 5, 1))
      t2 = make_trx(account, amount: BigDecimal("50"),  trx_date: Date.new(2026, 5, 2))

      # Move t2 before t1
      t2.update!(trx_date: Date.new(2026, 4, 15))

      expect(running_balance_for(t2)).to eq(BigDecimal("50"))
      expect(running_balance_for(t1)).to eq(BigDecimal("150"))
    end

    it "recomputes when pending flips" do
      reviewed = make_trx(account, amount: BigDecimal("100"), trx_date: Date.new(2026, 6, 1), pending: false)
      pending  = make_trx(account, amount: BigDecimal("40"),  trx_date: Date.new(2026, 5, 1), pending: true)

      # Flipping pending → false makes this row use its earlier trx_date for ordering.
      pending.update!(pending: false)

      expect(running_balance_for(pending)).to eq(BigDecimal("40"))
      expect(running_balance_for(reviewed)).to eq(BigDecimal("140"))
    end

    it "recomputes when a row is deleted" do
      t1 = make_trx(account, amount: BigDecimal("100"), trx_date: Date.new(2026, 7, 1))
      t2 = make_trx(account, amount: BigDecimal("50"),  trx_date: Date.new(2026, 7, 2))
      t3 = make_trx(account, amount: BigDecimal("25"),  trx_date: Date.new(2026, 7, 3))

      t2.destroy!

      expect(running_balance_for(t1)).to eq(BigDecimal("100"))
      expect(running_balance_for(t3)).to eq(BigDecimal("125"))
    end
  end

  describe "association from Transaction" do
    it "is reachable via Transaction#transaction_balance" do
      trx = make_trx(account, amount: BigDecimal("42"), trx_date: Date.new(2026, 8, 1))
      expect(trx.transaction_balance).to be_a(TransactionBalance)
      expect(trx.transaction_balance.running_balance).to eq(BigDecimal("42"))
    end

    it "exposes running_balance via Transaction#running_balance delegate" do
      trx = make_trx(account, amount: BigDecimal("42"), trx_date: Date.new(2026, 8, 1))
      expect(trx.running_balance).to eq(BigDecimal("42"))
    end
  end

  describe "view write protection" do
    it "is read-only — INSERT is a no-op via the INSTEAD rule" do
      # Postgres rules silently drop writes (CREATE RULE … DO INSTEAD NOTHING).
      # Confirming the view stays empty after a raw INSERT guards the protection.
      ActiveRecord::Base.connection.execute(
        "INSERT INTO transaction_balances (transaction_id, running_balance) VALUES (-1, 999)"
      )
      expect(TransactionBalance.find_by(transaction_id: -1)).to be_nil
    end
  end
end
