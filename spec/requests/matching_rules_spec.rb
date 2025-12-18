# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MatchingRules", type: :request do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }

  before { sign_in user }

  describe "GET /matching_rules" do
    it "returns http success" do
      get matching_rules_path
      expect(response).to have_http_status(:success)
    end

    it "lists the user's matching rules" do
      rule = create(:category_lookup, user: user, category: category, description_norm: "test")
      get matching_rules_path
      expect(response.body).to include("test")
    end

    context "with filters" do
      let!(:groceries_cat) { create(:category, user: user, name: "Groceries") }
      let!(:dining_cat) { create(:category, user: user, name: "Dining") }
      let!(:rule1) { create(:category_lookup, user: user, category: groceries_cat, description_norm: "whole foods") }
      let!(:rule2) { create(:category_lookup, user: user, category: dining_cat, description_norm: "chipotle") }

      it "filters by description" do
        get matching_rules_path, params: { description: "whole" }
        expect(response.body).to include("whole foods")
        expect(response.body).not_to include("chipotle")
      end

      it "filters by category" do
        get matching_rules_path, params: { category_id: groceries_cat.id }
        expect(response.body).to include("whole foods")
        expect(response.body).not_to include("chipotle")
      end
    end
  end

  describe "GET /matching_rules/new" do
    it "returns http success" do
      get new_matching_rule_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /matching_rules" do
    it "creates a new matching rule" do
      expect {
        post matching_rules_path, params: { category_lookup: { description_norm: "new rule", category_id: category.id } }
      }.to change(CategoryLookup, :count).by(1)
    end

    it "redirects to index on success" do
      post matching_rules_path, params: { category_lookup: { description_norm: "new rule", category_id: category.id } }
      expect(response).to redirect_to(matching_rules_path)
    end
  end

  describe "GET /matching_rules/:id/edit" do
    let(:rule) { create(:category_lookup, user: user, category: category) }

    it "returns http success" do
      get edit_matching_rule_path(rule)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /matching_rules/:id" do
    let(:rule) { create(:category_lookup, user: user, category: category, description_norm: "old") }
    let(:new_category) { create(:category, user: user, name: "NewCat") }

    it "updates the matching rule" do
      patch matching_rule_path(rule), params: { category_lookup: { description_norm: "updated", category_id: new_category.id } }
      rule.reload
      expect(rule.description_norm).to eq("updated")
      expect(rule.category).to eq(new_category)
    end

    it "redirects to index on success" do
      patch matching_rule_path(rule), params: { category_lookup: { description_norm: "updated", category_id: category.id } }
      expect(response).to redirect_to(matching_rules_path)
    end
  end

  describe "DELETE /matching_rules/:id" do
    let!(:rule) { create(:category_lookup, user: user, category: category) }

    it "deletes the matching rule" do
      expect {
        delete matching_rule_path(rule)
      }.to change(CategoryLookup, :count).by(-1)
    end
  end
end

