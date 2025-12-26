# frozen_string_literal: true

require "rails_helper"

RSpec.describe Category, type: :model do
  it "has a valid factory" do
    expect(build(:category)).to be_valid
    expect(build(:category, :global)).to be_valid
  end

  it { is_expected.to define_enum_for(:kind).with_values(global: 0, custom: 1) }
  it { is_expected.to belong_to(:user).optional }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_most(80) }

  it "normalizes the name" do
    category = build(:category, name: "  Grocery  ")
    category.validate
    expect(category.name).to eq("Grocery")
  end

  it "enforces uniqueness per user (case-insensitive)" do
    user = create(:user)
    create(:category, user: user, name: "Groceries")

    duplicate = build(:category, user: user, name: "groceries")
    expect(duplicate).not_to be_valid
  end

  it "allows the same name for different users" do
    create(:category, user: create(:user), name: "Dining")
    other = build(:category, user: create(:user), name: "Dining")
    expect(other).to be_valid
  end

  it "allows a custom category to reuse a global name" do
    create(:category, :global, name: "Reuse-Global")
    custom = build(:category, user: create(:user), name: "Reuse-Global")
    expect(custom).to be_valid
  end

  describe "#global?" do
    it "returns true for global categories" do
      category = build(:category, :global)
      expect(category.global?).to be true
    end

    it "returns false for custom categories" do
      category = build(:category, user: create(:user))
      expect(category.global?).to be false
    end
  end

  describe ".for_user scope" do
    let(:user) { create(:user) }
    let!(:global_category) { create(:category, :global, name: "Global") }
    let!(:user_category) { create(:category, user: user, name: "MyCategory") }
    let!(:other_user_category) { create(:category, user: create(:user), name: "OtherUser") }

    it "includes global categories" do
      expect(Category.for_user(user)).to include(global_category)
    end

    it "includes user's custom categories" do
      expect(Category.for_user(user)).to include(user_category)
    end

    it "excludes other users' custom categories" do
      expect(Category.for_user(user)).not_to include(other_user_category)
    end

    context "with hidden categories" do
      before do
        create(:hidden_category, user: user, category: global_category)
      end

      it "excludes hidden global categories" do
        expect(Category.for_user(user)).not_to include(global_category)
      end

      it "still includes the global category for other users" do
        other_user = create(:user)
        expect(Category.for_user(other_user)).to include(global_category)
      end
    end
  end
end

