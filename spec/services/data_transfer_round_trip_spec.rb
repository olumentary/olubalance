# frozen_string_literal: true

require "rails_helper"

# Exercises the real export → import pipeline end to end. The request specs only
# enqueue the jobs, so the Builder and Restorer were never executed under test —
# this spec runs both against the database to catch serialization / FK-remapping
# / unknown-attribute regressions.
RSpec.describe "DataTransfer round trip", type: :service do
  let(:source) { create(:user, :confirmed) }
  let(:target) { create(:user, :confirmed) }
  # find_or_create_by! — CI seeds the test DB (db:reset), so global categories
  # like "Groceries" may already exist; a plain create would hit the unique-name
  # validation. Globals are resolved by name on import, so reusing it is correct.
  let(:global_category) { Category.find_or_create_by!(name: "Groceries", kind: :global, user_id: nil) }

  def build_zip_for(user)
    export = create(:data_export, user: user)
    tempfile = DataExport::Builder.new(user: user, data_export: export).call
    tempfile.rewind
    path = "#{Dir.mktmpdir}/export.zip"
    File.binwrite(path, tempfile.read)
    tempfile.close
    path
  end

  it "round-trips accounts, transactions, bills, stashes, categories and attachments to a new user" do
    # --- build a realistic data set on the source user ---
    account = create(:account, user: source, name: "Main Checking", starting_balance: BigDecimal("500"))
    custom_cat = create(:category, user: source, name: "Hobbies")

    txn = create(:transaction, :non_pending, account: account, description: "Coffee",
                                              amount: BigDecimal("4.50"), category: custom_cat)
    txn.attachments.attach(
      io: StringIO.new("receipt-bytes"),
      filename: "receipt.txt",
      content_type: "text/plain"
    )

    create(:bill, account: account, user: source, category: global_category,
                  description: "Internet", amount: BigDecimal("80.00"))

    stash = create(:stash, account: account, name: "Vacation", goal: BigDecimal("1000"), balance: BigDecimal("0"))
    create(:stash_entry, stash: stash, amount: BigDecimal("25"), stash_action: "add")

    source.update!(default_account_id: account.id)

    zip_path = build_zip_for(source)

    # --- restore into the target user ---
    expect {
      DataImport::Restorer.new(user: target, zip_path: zip_path).call
    }.not_to raise_error

    # --- assertions: data landed under the target user with new IDs ---
    expect(target.accounts.count).to eq(1)
    new_account = target.accounts.first
    expect(new_account.name).to eq("Main Checking")
    expect(new_account.id).not_to eq(account.id)

    new_txn = new_account.transactions.find_by(description: "Coffee")
    expect(new_txn).to be_present
    # debits are stored negative (convert_amount); the round trip preserves it verbatim
    expect(new_txn.amount).to eq(txn.reload.amount)
    expect(new_txn.category.name).to eq("Hobbies")
    expect(new_txn.attachments.count).to eq(1)
    expect(new_txn.attachments.first.download).to eq("receipt-bytes")

    new_bill = target.bills.find_by(description: "Internet")
    expect(new_bill).to be_present
    expect(new_bill.account_id).to eq(new_account.id)
    expect(new_bill.category.name).to eq("Groceries")

    new_stash = new_account.stashes.find_by(name: "Vacation")
    expect(new_stash).to be_present
    expect(new_stash.stash_entries.count).to eq(1)

    expect(target.reload.default_account_id).to eq(new_account.id)
  end

  it "replaces the target user's pre-existing data" do
    # target already has data that must be wiped on import
    old_account = create(:account, user: target, name: "Old Account")
    create(:transaction, :non_pending, account: old_account, description: "Old txn", amount: BigDecimal("9"))

    # source has its own single account
    create(:account, user: source, name: "Fresh Account", starting_balance: BigDecimal("100"))
    zip_path = build_zip_for(source)

    DataImport::Restorer.new(user: target, zip_path: zip_path).call

    target.reload
    expect(target.accounts.pluck(:name)).to eq([ "Fresh Account" ])
    expect(Account.where(id: old_account.id)).to be_empty
  end

  it "links counterpart transfer transactions on both sides after import" do
    account_a = create(:account, user: source, name: "Acct A", starting_balance: BigDecimal("100"))
    account_b = create(:account, user: source, name: "Acct B", starting_balance: BigDecimal("100"))

    # mimic a transfer: two transactions linked via counterpart_transaction_id
    t1 = create(:transaction, :non_pending, account: account_a, description: "Transfer out", amount: BigDecimal("10"))
    t2 = create(:transaction, :non_pending, account: account_b, description: "Transfer in", amount: BigDecimal("10"))
    t1.update_column(:counterpart_transaction_id, t2.id)
    t2.update_column(:counterpart_transaction_id, t1.id)

    zip_path = build_zip_for(source)
    DataImport::Restorer.new(user: target, zip_path: zip_path).call

    new_t1 = Transaction.joins(:account).where(accounts: { user_id: target.id }).find_by(description: "Transfer out")
    new_t2 = Transaction.joins(:account).where(accounts: { user_id: target.id }).find_by(description: "Transfer in")

    expect(new_t1.counterpart_transaction_id).to eq(new_t2.id)
    expect(new_t2.counterpart_transaction_id).to eq(new_t1.id)
  end
end
