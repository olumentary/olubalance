# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  it "has a valid factory" do
    expect(FactoryBot.build(:user)).to be_valid
  end
  
  describe "user sign up" do
    let!(:user) { FactoryBot.create(:user, confirmed_at: nil) }
    
    it "should send the user a confirmation email on signup" do
      expect(Devise.mailer.deliveries.count).to eq 1
    end

    it "should send the user a confirmation email when email changes" do
      user.update(email: "new-email@gmail.com")
      expect(Devise.mailer.deliveries.count).to eq 2
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:first_name).with_message('Please enter your First Name') }
    it { is_expected.to validate_presence_of(:last_name).with_message('Please enter your Last Name') }
    it { is_expected.to validate_presence_of(:timezone).with_message('Please select a Time Zone') }
    it { is_expected.to validate_presence_of(:password) }
    it { is_expected.to validate_length_of(:password) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to allow_value('test@gmail.com').for(:email) }
    it { is_expected.to_not allow_value('asdf').for(:email) }
  end

  it { should have_many(:accounts) }
  it { should belong_to(:default_account).class_name('Account').optional }

  describe 'default account validation' do
    let(:user) { FactoryBot.create(:user) }
    let(:other_user) { FactoryBot.create(:user) }
    let(:user_account) { FactoryBot.create(:account, user: user) }
    let(:other_user_account) { FactoryBot.create(:account, user: other_user) }

    it 'allows setting a default account that belongs to the user' do
      user.default_account_id = user_account.id
      expect(user).to be_valid
    end

    it 'does not allow setting a default account that belongs to another user' do
      user.default_account_id = other_user_account.id
      expect(user).not_to be_valid
      expect(user.errors[:default_account_id]).to include('must be one of your accounts')
    end

    it 'allows nil default account' do
      user.default_account_id = nil
      expect(user).to be_valid
    end
  end
end
