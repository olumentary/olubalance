# frozen_string_literal: true

require "rails_helper"

RSpec.describe CategorySuggester do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:category) { create(:category, user: user, name: "Groceries") }

  describe "#suggest" do
    it "prefers lookup matches over AI" do
      CategoryLookup.upsert_for(user: user, category: category, description: "Whole Foods")
      ai_client = instance_double(AiCategoryClient)
      allow(ai_client).to receive(:suggest).and_return(nil)

      suggestion = described_class.new(user: user, ai_client: ai_client).suggest("Whole Foods")

      expect(suggestion.category).to eq(category)
      expect(suggestion.source).to eq(:lookup)
      expect(ai_client).not_to have_received(:suggest)
    end

    it "falls back to AI when no lookup exists" do
      ai_category = create(:category, :global, name: "Dining-Rspec")
      ai_client = instance_double(AiCategoryClient)
      allow(ai_client).to receive(:suggest).and_return(
        CategorySuggester::Suggestion.new(category: ai_category, confidence: 0.6, source: :ai)
      )

      suggestion = described_class.new(user: user, ai_client: ai_client).suggest("Chipotle")

      expect(suggestion.category).to eq(ai_category)
      expect(suggestion.source).to eq(:ai)
    end
  end
end

