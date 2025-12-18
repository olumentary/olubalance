# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Categories", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }

  before { sign_in user }

  describe "GET /categories" do
    it "returns http success" do
      get categories_path
      expect(response).to have_http_status(:success)
    end

    it "lists the user's categories" do
      custom = create(:category, user: user, name: "MyCustom")
      get categories_path
      expect(response.body).to include("MyCustom")
    end

    it "lists global categories" do
      global = create(:category, :global, name: "GlobalCat")
      get categories_path
      expect(response.body).to include("GlobalCat")
    end

    it "does not list hidden global categories" do
      global = create(:category, :global, name: "HiddenGlobal")
      create(:hidden_category, user: user, category: global)
      get categories_path
      expect(response.body).not_to include("HiddenGlobal")
    end
  end

  describe "POST /categories" do
    it "creates a custom category for the user" do
      expect {
        post categories_path, params: { category: { name: "NewCategory" } }
      }.to change { user.categories.count }.by(1)
    end

    it "sets kind to custom" do
      post categories_path, params: { category: { name: "NewCategory" } }
      expect(Category.last.custom?).to be true
    end
  end

  describe "GET /categories/:id/edit" do
    let(:category) { create(:category, user: user, name: "EditMe") }

    it "returns http success" do
      get edit_category_path(category)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /categories/:id" do
    context "with a custom category" do
      let(:category) { create(:category, user: user, name: "OldName") }

      it "updates the category name" do
        patch category_path(category), params: { category: { name: "NewName" } }
        category.reload
        expect(category.name).to eq("NewName")
      end

      it "redirects to index" do
        patch category_path(category), params: { category: { name: "NewName" } }
        expect(response).to redirect_to(categories_path)
      end
    end

    context "with a global category" do
      let!(:global) { create(:category, :global, name: "GlobalOriginal") }
      let!(:transaction) { create(:transaction, :non_pending, account: account, category: global) }
      let!(:lookup) { create(:category_lookup, user: user, category: global, description_norm: "test") }

      it "creates a custom copy for the user" do
        expect {
          patch category_path(global), params: { category: { name: "MyRenamedGlobal" } }
        }.to change { user.categories.count }.by(1)
      end

      it "hides the original global category" do
        patch category_path(global), params: { category: { name: "MyRenamedGlobal" } }
        expect(HiddenCategory.exists?(user: user, category: global)).to be true
      end

      it "reassigns user transactions to the new category" do
        patch category_path(global), params: { category: { name: "MyRenamedGlobal" } }
        transaction.reload
        expect(transaction.category.name).to eq("MyRenamedGlobal")
        expect(transaction.category.user).to eq(user)
      end

      it "reassigns user lookups to the new category" do
        patch category_path(global), params: { category: { name: "MyRenamedGlobal" } }
        lookup.reload
        expect(lookup.category.name).to eq("MyRenamedGlobal")
      end
    end
  end

  describe "DELETE /categories/:id" do
    context "with a custom category" do
      let!(:category) { create(:category, user: user, name: "ToDelete") }
      let!(:transaction) { create(:transaction, :non_pending, account: account, category: category) }

      it "destroys the category" do
        expect {
          delete category_path(category)
        }.to change(Category, :count).by(-1)
      end

      it "nullifies transactions" do
        delete category_path(category)
        transaction.reload
        expect(transaction.category).to be_nil
      end
    end

    context "with a global category" do
      let!(:global) { create(:category, :global, name: "GlobalToHide") }
      let!(:transaction) { create(:transaction, :non_pending, account: account, category: global) }

      it "does not destroy the global category" do
        expect {
          delete category_path(global)
        }.not_to change(Category, :count)
      end

      it "creates a hidden_category record" do
        expect {
          delete category_path(global)
        }.to change(HiddenCategory, :count).by(1)
      end

      it "nullifies the user's transactions" do
        delete category_path(global)
        transaction.reload
        expect(transaction.category).to be_nil
      end

      it "does not affect other users' transactions" do
        other_user = create(:user)
        other_account = create(:account, user: other_user)
        other_transaction = create(:transaction, :non_pending, account: other_account, category: global)

        delete category_path(global)
        other_transaction.reload
        expect(other_transaction.category).to eq(global)
      end
    end
  end
end

