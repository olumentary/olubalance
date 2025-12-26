require 'rails_helper'

RSpec.describe PerformTransfer, type: :model do

  describe 'do transfer' do
    let(:user) { FactoryBot.create(:user) }
    let!(:source_account) { FactoryBot.create(:account, name: 'Source Account', user: user) }
    let!(:target_account) { FactoryBot.create(:account, name: 'Target Account', user: user) }

    it 'updates the source and target account balances' do
      amount = 500
      PerformTransfer.new(source_account.id, target_account.id, amount).do_transfer
      source_account.reload
      expect(source_account.current_balance).to eq (source_account.starting_balance - amount)
      target_account.reload
      expect(target_account.current_balance).to eq (target_account.starting_balance + amount)
    end

    describe 'transfer transactions' do
      let!(:amount) { 1000 }
      let!(:transfer) { PerformTransfer.new(source_account.id, target_account.id, amount).do_transfer }
      let!(:source_transaction) { source_account.transactions.last }
      let!(:target_transaction) { target_account.transactions.last }

      it 'creates a source account transaction' do
        expect(source_transaction.transaction_type).to include ('debit')
        expect(source_transaction.account_id).to eq source_account.id
        expect(source_transaction.description).to eq 'Transfer to ' + target_account.name
        expect(source_transaction.amount).to be < 0
        expect(source_transaction.amount).to eq -amount.to_d
        expect(source_transaction.locked).to be true
        expect(source_transaction.transfer).to be true
        expect(source_transaction.category.name).to eq 'Transfer'
      end

      it 'creates a target account transaction' do
        expect(target_transaction.transaction_type).to include ('credit')
        expect(target_transaction.account_id).to eq target_account.id
        expect(target_transaction.description).to eq 'Transfer from ' + source_account.name
        expect(target_transaction.amount).to be > 0
        expect(target_transaction.amount).to eq amount.to_d
        expect(target_transaction.locked).to be true
        expect(target_transaction.transfer).to be true
        expect(target_transaction.category.name).to eq 'Transfer'
      end
    end
  end
end
