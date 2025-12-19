# frozen_string_literal: true

require "rails_helper"

RSpec.describe HiddenCategory, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:category) }
  end

  describe "validations" do
    subject { create(:hidden_category) }
    it { should validate_uniqueness_of(:category_id).scoped_to(:user_id) }
  end

  describe "uniqueness" do
    let(:user) { create(:user) }
    let(:category) { create(:category, :global) }

    it "allows hiding a category once per user" do
      create(:hidden_category, user: user, category: category)
      duplicate = build(:hidden_category, user: user, category: category)
      expect(duplicate).not_to be_valid
    end

    it "allows different users to hide the same category" do
      other_user = create(:user)
      create(:hidden_category, user: user, category: category)
      hidden = build(:hidden_category, user: other_user, category: category)
      expect(hidden).to be_valid
    end
  end
end

