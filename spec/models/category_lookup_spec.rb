# frozen_string_literal: true

require "rails_helper"

RSpec.describe CategoryLookup, type: :model do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }

  describe ".normalize" do
    it "downcases and squishes whitespace" do
      expect(described_class.normalize("  Whole   Foods ")).to eq("whole foods")
    end
  end

  describe ".upsert_for" do
    it "creates and increments usage_count" do
      lookup = described_class.upsert_for(user: user, category: category, description: "Whole Foods")
      expect(lookup.description_norm).to eq("whole foods")
      expect(lookup.usage_count).to eq(1)

      lookup2 = described_class.upsert_for(user: user, category: category, description: "Whole Foods")
      expect(lookup2.id).to eq(lookup.id)
      expect(lookup2.usage_count).to eq(2)
    end

    it "returns nil for blank description" do
      expect(described_class.upsert_for(user: user, category: category, description: "   ")).to be_nil
    end
  end

  describe ".suggest_for" do
    it "returns exact matches first" do
      described_class.upsert_for(user: user, category: category, description: "Whole Foods")
      suggestion = described_class.suggest_for(user: user, description: "whole foods")
      expect(suggestion.category).to eq(category)
    end

    it "returns fuzzy matches when similar" do
      described_class.upsert_for(user: user, category: category, description: "Trader Joe's")
      suggestion = described_class.suggest_for(user: user, description: "trader joes")
      expect(suggestion.category).to eq(category)
    end
  end
end

