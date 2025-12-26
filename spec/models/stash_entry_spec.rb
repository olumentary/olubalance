require 'rails_helper'

RSpec.describe StashEntry, type: :model do
  it "has a valid factory" do
    stash = FactoryBot.create(:stash)
    expect(FactoryBot.build(:stash_entry, stash: stash)).to be_valid
    expect(FactoryBot.build(:stash_entry, :remove, stash: stash)).to be_valid
  end

  describe 'stash entry initialization' do
    let(:stash) { FactoryBot.create(:stash) }
    let!(:stash_entry) { FactoryBot.create(:stash_entry, stash: stash) }
    let!(:stash_entry_remove) { FactoryBot.create(:stash_entry, :remove, stash: stash) }

    it 'sets the stash before save' do
      expect(stash_entry.stash_id).to eq stash.id
    end

    it 'sets stash entry default values' do
      expect(stash_entry.amount).to be > 0
      expect(stash_entry_remove.amount).to be < 0
      expect(stash_entry.description).to eq StashEntry::STASH_ADD_DESC
      expect(stash_entry_remove.description).to eq StashEntry::STASH_REMOVE_DESC
      # TODO: Set up Timecop gem to test for stash entry date default value = Current Date
    end
  end

  describe 'stash balance update' do
    let(:stash) { FactoryBot.create(:stash) }
    let!(:original_balance) { stash.balance }
    let!(:stash_entry) { FactoryBot.create(:stash_entry, stash: stash) }

    it 'updates the stash balance' do
      stash.reload
      expect(stash.balance).to eq (original_balance + stash_entry.amount)
    end
  end

  describe 'stash transaction creation' do
    let!(:stash) { FactoryBot.create(:stash) }
    let!(:stash_entry) { FactoryBot.create(:stash_entry, stash: stash) }

    it 'creates a transaction in the correct account with appropriate values' do
      transaction = Transaction.last
      expect(transaction.amount.abs).to eq stash_entry.amount.abs
      expect(transaction.account_id).to eq stash.account_id
      expect(transaction.description).to eq 'Transfer to ' + stash.name + ' Stash'
      expect(transaction.locked).to be true
      expect(transaction.category.name).to eq 'Transfer'
    end
  end

  # Trouble getting shoulda_matchers to work with the stash_entry validation
  # stash_balance_out_of_bounds. Using standard RSpec for now.
  describe 'validations' do
    let!(:stash) { FactoryBot.create(:stash) }
    # let!(:stash_entry) { FactoryBot.create(:stash_entry, stash: stash) }

    it 'is invalid without a stash action' do
      stash_entry = FactoryBot.build(:stash_entry, stash: stash, stash_action: nil)
      stash_entry.valid?
      expect(stash_entry.errors[:stash_action]).to include('is not included in the list')
    end

    it 'is invalid with an invalid stash action' do
      stash_entry = FactoryBot.build(:stash_entry, stash: stash, stash_action: 'asdf')
      stash_entry.valid?
      expect(stash_entry.errors[:stash_action]).to include('is not included in the list')
    end

    it 'is invalid without an amount' do
      stash_entry = FactoryBot.build(:stash_entry, stash: stash, amount: nil)
      stash_entry.valid?
      expect(stash_entry.errors[:amount]).to include("can't be blank")
    end

    it 'is invalid with a negative amount' do
      stash_entry = FactoryBot.build(:stash_entry, stash: stash, amount: -50)
      stash_entry.valid?
      expect(stash_entry.errors[:amount]).to include("must be greater than 0")
    end
    
    it 'should belong to a stash' do
      stash_entry = FactoryBot.build(:stash_entry, stash: stash)
      stash_entry.valid?
      expect(stash_entry.stash).to eq (stash)
    end

    it 'should not allow the stash balance to become negative' do
      stash_entry = FactoryBot.build(:stash_entry, :remove, stash: stash, stash_action: 'remove', amount: 50000)
      stash_entry.valid?
      expect(stash_entry.errors[:amount]).to include("can't cause the stash balance to become negative")
    end

    it 'should not allow the stash balance to exceed the goal' do
      stash_entry = FactoryBot.build(:stash_entry, stash: stash, amount: 50000)
      stash_entry.valid?
      expect(stash_entry.errors[:amount]).to include("can't cause the stash balance to exceed the goal")
    end
  end

end
