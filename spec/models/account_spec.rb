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
        FactoryBot.create(:transaction, :credit_transaction, :non_pending, account: account, amount: amt)
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

  describe 'statement_day validation' do
    it { should allow_value(nil).for(:statement_day) }
    it { should allow_value(1).for(:statement_day) }
    it { should allow_value(31).for(:statement_day) }
    it { should_not allow_value(0).for(:statement_day) }
    it { should_not allow_value(32).for(:statement_day) }
    it { should_not allow_value(15.5).for(:statement_day) }
  end

  describe 'interest helpers' do
    let(:user) { FactoryBot.create(:user) }
    let(:account) do
      FactoryBot.create(:account, :credit,
                        user: user,
                        starting_balance: -500,
                        interest_rate: 24.0,
                        statement_day: 15)
    end

    describe '#interest_eligible?' do
      it 'is true for a credit account with rate, statement_day, and a negative balance' do
        expect(account.interest_eligible?).to be true
      end

      it 'is false when the account is not credit' do
        non_credit = FactoryBot.create(:account, :checking, user: user)
        expect(non_credit.interest_eligible?).to be false
      end

      it 'is false when interest_rate is zero' do
        account.update_column(:interest_rate, 0)
        expect(account.reload.interest_eligible?).to be false
      end

      it 'is false when statement_day is nil' do
        account.update_column(:statement_day, nil)
        expect(account.reload.interest_eligible?).to be false
      end

      it 'is false when the balance is non-negative (nothing owed)' do
        account.update_column(:current_balance, 0)
        expect(account.reload.interest_eligible?).to be false
      end
    end

    describe '#clamped_statement_day' do
      it 'returns statement_day for months with enough days' do
        account.update_column(:statement_day, 31)
        expect(account.clamped_statement_day(Date.new(2026, 1, 1))).to eq 31
      end

      it 'clamps to the last day of February' do
        account.update_column(:statement_day, 31)
        expect(account.clamped_statement_day(Date.new(2026, 2, 1))).to eq 28
      end
    end

    describe '#interest_due_on?' do
      it 'is true when the date day matches the statement day and nothing was charged this month' do
        expect(account.interest_due_on?(Date.new(2026, 5, 15))).to be true
      end

      it 'is false on a different day' do
        expect(account.interest_due_on?(Date.new(2026, 5, 14))).to be false
      end

      it 'is false when already charged this month' do
        account.update_column(:last_interest_charged_on, Date.new(2026, 5, 15))
        expect(account.interest_due_on?(Date.new(2026, 5, 15))).to be false
      end

      it 'is true again the following month after a prior charge' do
        account.update_column(:last_interest_charged_on, Date.new(2026, 4, 15))
        expect(account.interest_due_on?(Date.new(2026, 5, 15))).to be true
      end

      it 'clamps statement_day=31 to month-end (e.g. Feb 28)' do
        account.update_column(:statement_day, 31)
        expect(account.interest_due_on?(Date.new(2026, 2, 28))).to be true
        expect(account.interest_due_on?(Date.new(2026, 2, 27))).to be false
      end
    end

    describe '#monthly_interest_amount' do
      it 'returns BigDecimal rounded to two places using APR/12' do
        # current_balance set to -500 by starting_balance; rate 24% => 500 * 24 / 1200 = 10.00
        amount = account.monthly_interest_amount
        expect(amount).to be_a(BigDecimal)
        expect(amount).to eq(BigDecimal("10.00"))
      end

      it 'is positive even when balance is negative' do
        expect(account.monthly_interest_amount).to be > 0
      end
    end
  end
end
