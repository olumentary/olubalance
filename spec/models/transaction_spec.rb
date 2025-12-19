# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Transaction, type: :model do
  it 'has a valid factory' do
    expect(FactoryBot.build(:transaction)).to be_valid
    expect(FactoryBot.build(:transaction, :credit_transaction)).to be_valid
  end

  # Transaction values are stored in DB as positive (credit) or negative (debit)
  # The transaction type is not stored in DB
  describe 'transaction amount conversion' do
    context 'debit transaction' do
      it 'should convert the amount to a negative value' do
        debit_transaction = FactoryBot.create(:transaction, :non_pending)
        expect(debit_transaction.amount).to be <= 0
      end
    end

    context 'credit transaction' do
      it 'should leave the amount as a positive value' do
        credit_transaction = FactoryBot.create(:transaction, :credit_transaction, :non_pending)
        expect(credit_transaction.amount).to be >= 0
      end
    end
  end

  describe 'account balance updates' do

    let(:account) { FactoryBot.create(:account) }
    let!(:original_balance) { account.current_balance }
    let!(:transaction) { FactoryBot.create(:transaction, :non_pending, account: account) }

    context 'create transaction' do
      it 'should update the account balance' do
        account.reload
        expect(account.current_balance).to eq original_balance + transaction.amount
      end
    end

    context 'update transaction' do
      it 'should update the account balance' do
        account.reload
        original_transaction_amount = transaction.amount
        expect(account.current_balance).to eq (original_balance + original_transaction_amount)
        
        new_transaction_amount = Faker::Number.decimal(l_digits: 2, r_digits: 2)
        transaction.update(amount: new_transaction_amount, trx_type: 'debit')
        account.reload
        expect(account.current_balance).to eq (original_balance + original_transaction_amount - original_transaction_amount + transaction.amount)
      end
    end

    context 'delete transaction' do
      it 'should update the account balance on destroy' do
        account.reload
        expect(account.current_balance).to eq (original_balance + transaction.amount)
        
        transaction.destroy
        account.reload
        expect(account.current_balance).to eq original_balance
      end
    end
  end

  describe 'transaction type return value' do
    context 'debit transaction' do
      it 'should return "debit" for negative value transactions' do
        transaction = FactoryBot.create(:transaction, :non_pending)
        expect(transaction.transaction_type).to include ('debit')
        expect(transaction.transaction_type).to include ('Debit')
      end
    end

    context 'credit transaction' do
      it 'should return "credit" for positive value transactions' do
        transaction = FactoryBot.create(:transaction, :credit_transaction, :non_pending)
        expect(transaction.transaction_type).to include ('credit')
        expect(transaction.transaction_type).to include ('Credit')
      end
    end
  end

  describe 'transaction search' do
    let(:account) { FactoryBot.create(:account) }
    let(:transaction1) { FactoryBot.create(:transaction, :non_pending, account: account, description: 'Test Transaction One') }
    let(:transaction2) { FactoryBot.create(:transaction, :non_pending, account: account, description: 'Test Transaction Two') }
    let(:transaction3) { FactoryBot.create(:transaction, :non_pending, account: account, description: 'Test Transaction Three') }

    it 'returns transactions that match the search term' do
      expect(Transaction.search("Test")).to include(transaction1, transaction2, transaction3)
      expect(Transaction.search("Two")).to include(transaction2)
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:trx_type).with_message('Please select debit or credit') }
    it { should validate_inclusion_of(:trx_type).in_array(%w[credit debit]) }
    it { should validate_presence_of(:trx_date) }
    it { should validate_presence_of(:description) }
    it { should validate_length_of(:description) }
    it { should validate_presence_of(:amount) }
    it { should validate_length_of(:memo) }
  end

  it { should belong_to(:account) }
  # it { is_expected.to have_one(:transaction_balance) }

  describe "category ownership validation" do
    let(:user) { FactoryBot.create(:user) }
    let(:other_user) { FactoryBot.create(:user) }
    let(:account) { FactoryBot.create(:account, user: user) }
    let(:category) { FactoryBot.create(:category, user: user) }
    let(:global_category) { FactoryBot.create(:category, :global) }

    it "allows a category that belongs to the account's user" do
      transaction = FactoryBot.build(:transaction, :non_pending, account: account, category: category)
      expect(transaction).to be_valid
    end

    it "rejects a category belonging to a different user" do
      other_category = FactoryBot.create(:category, user: other_user)
      transaction = FactoryBot.build(:transaction, :non_pending, account: account, category: other_category)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:category_id]).to include("must belong to the same user")
    end

    it "allows a global category" do
      transaction = FactoryBot.build(:transaction, :non_pending, account: account, category: global_category)
      expect(transaction).to be_valid
    end
  end

  describe 'amount validation and balance updates' do
    let(:user) { FactoryBot.create(:user) }
    let(:account) { FactoryBot.create(:account, user: user, starting_balance: 1000) }
    let(:transaction) { FactoryBot.create(:transaction, account: account, amount: 100) }

    it 'does not update account balance when amount is invalid' do
      account.reload
      initial_balance = account.current_balance
      
      # Try to update with invalid amount
      transaction.amount = 'invalid_amount'
      transaction.save
      
      # Account balance should remain unchanged
      account.reload
      expect(account.current_balance).to eq(initial_balance)
    end

    it 'does not update account balance when amount is not numeric' do
      account.reload
      initial_balance = account.current_balance
      
      # Try to update with non-numeric amount
      transaction.amount = 'asdf'
      transaction.save
      
      # Account balance should remain unchanged
      account.reload
      expect(account.current_balance).to eq(initial_balance)
    end

    it 'does not update account balance when amount is invalid string' do
      account.reload
      initial_balance = account.current_balance
      
      # Try to update with invalid string
      transaction.amount = 'not_a_number'
      transaction.save
      
      # Account balance should remain unchanged
      account.reload
      expect(account.current_balance).to eq(initial_balance)
    end

    it 'allows valid amount updates to proceed' do
      account.reload
      initial_balance = account.current_balance
      
      # Update with valid amount
      transaction.amount = 200
      result = transaction.save
      
      # The save should succeed (not fail validation)
      expect(result).to be true
      expect(transaction.errors).to be_empty
    end
  end
end
