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
    create(:category, :global, name: "Travel")
    custom = build(:category, user: create(:user), name: "Travel")
    expect(custom).to be_valid
  end
end

