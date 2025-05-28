# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Account, type: :model do
  it "has a valid factory" do
    expect(FactoryBot.build(:account)).to be_valid
  end

  describe 'account creation' do
    let(:account) { FactoryBot.create(:account) }
    
    it 'should set the current balance to the starting balance' do
      expect(account.current_balance).to_not eq nil
      expect(account.current_balance).to eq account.starting_balance
    end

    it 'should create initial transaction' do
      expect(account.transactions.first.account_id).to eq account.id
    end

    it 'sets the initial transaction locked flag to true' do
      expect(account.transactions.first.locked).to be true
    end
  end

  describe 'pending and non-pending balances' do

    # Set up account and define some pending/non-pending amounts, and calculate totals
    let(:account) { FactoryBot.create(:account) }
    let(:pending_amts) { [20, 140, 500] }
    let(:non_pending_amts) { [120, 80, 900] }
    let(:total_pending) { pending_amts.sum }
    let(:total_non_pending) { non_pending_amts.sum + account.current_balance }

    # Create transactions in pending/non-pending status
    before do
      pending_amts.each do |amt|
        FactoryBot.create(:transaction, :credit_transaction, account: account, amount: amt, pending: true)
      end

      non_pending_amts.each do |amt|
        FactoryBot.create(:transaction, :credit_transaction, account: account, amount: amt, skip_pending_default: true)
      end
    end

    context 'pending balance' do
      it 'returns the balance of pending transactions' do
        expect(account.pending_balance).to eq total_pending
      end
    end

    context 'non-pending balance' do
      it 'returns the balance of non-pending transactions' do
        expect(account.non_pending_balance).to eq total_non_pending
      end
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:starting_balance) }
    it { should allow_value(150.51).for(:starting_balance) }
    it { should validate_uniqueness_of(:name).scoped_to(:user_id) }
    it { should allow_value('My Account').for(:name) }
    it { should_not allow_value('A').for(:name) }
    it { should_not allow_value('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA').for(:name) }
    it { should allow_value('1234').for(:last_four) }
    it { should allow_value(nil).for(:last_four) }
    it { should_not allow_value('12').for(:last_four) }
    it { should_not allow_value('12345').for(:last_four) }
    it { should_not allow_value('ASDF').for(:last_four) }
    it { should define_enum_for(:account_type).with_values(checking: 'checking', credit: 'credit', cash: 'cash', savings: 'savings').backed_by_column_of_type(:enum) }

    context 'credit account' do
      before { allow(subject).to receive(:credit?).and_return(true) }
      it { should validate_presence_of(:interest_rate) }
      it { should allow_value(20.00).for(:interest_rate) }
      it { should_not allow_value('ASDF').for(:interest_rate) }
      it { should_not allow_value(-10.00).for(:interest_rate) }
      it { should validate_presence_of(:credit_limit) }
      it { should allow_value(9000.00).for(:credit_limit) }
      it { should_not allow_value('ASDF').for(:credit_limit) }
      it { should_not allow_value(-5000.00).for(:credit_limit) }
    end

    context 'savings account' do
      before { allow(subject).to receive(:savings?).and_return(true) }
      it { should validate_presence_of(:interest_rate) }
      it { should allow_value(20.00).for(:interest_rate) }
      it { should_not allow_value('ASDF').for(:interest_rate) }
      it { should_not allow_value(-10.00).for(:interest_rate) }
    end
  end

  it { should belong_to(:user) }
  it { should have_many(:transactions) }
  it { should have_many(:stashes) }
end
