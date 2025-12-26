# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiCategoryClient do
  describe "#suggest" do
    it "returns a suggestion when the response maps to a known category" do
      category = create(:category, :global, name: "Groceries-Rspec")
      fake_response = {
        "choices" => [
          { "message" => { "content" => { category: "Groceries-Rspec", confidence: 0.8 }.to_json } }
        ]
      }
      client = described_class.new(client: instance_double(OpenAI::Client, chat: fake_response))

      suggestion = client.suggest(description: "Whole Foods Market", categories: [category])

      expect(suggestion.category).to eq(category)
      expect(suggestion.confidence).to eq(0.8)
      expect(suggestion.source).to eq(:ai)
    end

    it "returns nil when no client is configured" do
      suggestion = described_class.new(client: nil).suggest(description: "Coffee", categories: [])
      expect(suggestion).to be_nil
    end
  end
end

