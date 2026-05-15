require "rails_helper"

RSpec.describe "Transfers", type: :request do
  let(:user)           { create(:user) }
  let!(:source_account) { create(:account, name: "Source", user: user, starting_balance: BigDecimal("1000")) }
  let!(:target_account) { create(:account, name: "Target", user: user, starting_balance: BigDecimal("100")) }

  describe "POST /transfers" do
    it "rejects unauthenticated requests" do
      expect {
        post transfers_path, params: {
          transfer_from_account: source_account.id,
          transfer_to_account:   target_account.id,
          transfer_amount:       "250.00",
          transfer_date:         Date.current.to_s
        }
      }.not_to change { Transaction.count }

      expect(response).to redirect_to(new_user_session_path)
    end

    context "between two of the signed-in user's accounts" do
      before { sign_in user }

      it "creates a debit + credit pair, updates both balances, and redirects with a success flash" do
        expect {
          post transfers_path, params: {
            transfer_from_account: source_account.id,
            transfer_to_account:   target_account.id,
            transfer_amount:       "250.00",
            transfer_date:         Date.current.to_s
          }
        }.to change { Transaction.count }.by(2)

        expect(response).to redirect_to(account_transactions_path(source_account.id))
        expect(flash[:notice]).to eq("Transfer successful.")

        source_account.reload
        target_account.reload
        expect(source_account.current_balance).to eq(BigDecimal("750"))
        expect(target_account.current_balance).to eq(BigDecimal("350"))

        debit  = source_account.transactions.order(:id).last
        credit = target_account.transactions.order(:id).last
        expect(debit.amount).to eq(BigDecimal("-250"))
        expect(credit.amount).to eq(BigDecimal("250"))
        expect(debit.counterpart_transaction_id).to eq(credit.id)
        expect(credit.counterpart_transaction_id).to eq(debit.id)
      end
    end

    context "when the target account belongs to another user (IDOR)" do
      let(:attacker) { create(:user) }
      let!(:victim_account) { create(:account, name: "Victim", user: attacker) }

      before { sign_in user }

      it "does not let a user transfer from their account into another user's account" do
        expect {
          post transfers_path, params: {
            transfer_from_account: source_account.id,
            transfer_to_account:   victim_account.id,
            transfer_amount:       "50.00",
            transfer_date:         Date.current.to_s
          }
        }.not_to change { Transaction.count }

        expect(response).to have_http_status(:not_found)
      end

      it "does not let a user transfer from another user's account" do
        expect {
          post transfers_path, params: {
            transfer_from_account: victim_account.id,
            transfer_to_account:   target_account.id,
            transfer_amount:       "50.00",
            transfer_date:         Date.current.to_s
          }
        }.not_to change { Transaction.count }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "deleting one side of a counterpart pair" do
    before { sign_in user }

    it "nullifies the counterpart link on the surviving row (dependent: :nullify)" do
      post transfers_path, params: {
        transfer_from_account: source_account.id,
        transfer_to_account:   target_account.id,
        transfer_amount:       "100",
        transfer_date:         Date.current.to_s
      }
      debit  = source_account.transactions.order(:id).last
      credit = target_account.transactions.order(:id).last
      expect(debit.counterpart_transaction_id).to eq(credit.id)

      # Direct destroy via the model (controller path is tested elsewhere).
      debit.destroy!

      credit.reload
      expect(credit.counterpart_transaction_id).to be_nil
    end
  end
end
