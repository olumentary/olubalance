require 'rails_helper'

RSpec.describe Stash, type: :model do
  it "has a valid factory" do
    expect(FactoryBot.build(:stash)).to be_valid
  end

  describe 'default stash values' do
    subject { FactoryBot.create(:stash) }
    it { expect(subject.active).to eq true }
  end

  describe 'stash emptied to account upon delete' do
    let(:account) { FactoryBot.create(:account) }
    let(:stash_balance) { 500 }
    let(:stash) {FactoryBot.create(:stash, account: account, balance: stash_balance) }

    it 'should return any stashed money to the account upon destroy' do
      expect {
       stash.destroy
      }.to change(account.transactions, :count).by(1)
      expect(account.transactions.last.amount).to eq (stash_balance)
      expect(account.transactions.last.description).to include ('Deleted')
      expect(account.transactions.last.category.name).to eq 'Transfer'
      account.reload
      expect(account.current_balance).to eq (account.starting_balance + stash_balance)
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:goal) }
    it { should validate_uniqueness_of(:name).scoped_to(:account_id) }
    it { should allow_value('My Stash').for(:name) }
    it { should_not allow_value('A').for(:name) }
    it { should_not allow_value('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA').for(:name) }
    it { should allow_value('10000.00').for(:goal) }
    it { should_not allow_value('ASDF').for(:goal) }
    it { should_not allow_value('-100.00').for(:goal) }
  end

  it { should belong_to(:account) }
  it { should have_many(:stash_entries) }
end
