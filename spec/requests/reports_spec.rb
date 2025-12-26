# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reports", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:category) { create(:category, user: user, name: "Groceries") }

  before { sign_in user }

  describe "GET /reports" do
    it "returns http success" do
      get reports_path
      expect(response).to have_http_status(:success)
    end

    it "displays the reports page" do
      get reports_path
      expect(response.body).to include("Spending Reports")
    end

    it "shows filter options" do
      get reports_path
      expect(response.body).to include("Start Date")
      expect(response.body).to include("End Date")
      expect(response.body).to include("Accounts")
      expect(response.body).to include("Categories")
    end

    context "with spending data" do
      before do
        create(:transaction, :non_pending, account: account, category: category,
               amount: -150, trx_date: Date.current, trx_type: "debit", pending: false)
      end

      it "displays the category name" do
        get reports_path
        expect(response.body).to include("Groceries")
      end

      it "displays spending amount" do
        get reports_path
        expect(response.body).to include("$150.00")
      end

      it "shows chart containers" do
        get reports_path
        expect(response.body).to include("spending-bar-chart")
        expect(response.body).to include("spending-donut-chart")
      end
    end

    context "with no spending data" do
      it "shows empty state message" do
        get reports_path
        expect(response.body).to include("No spending data found")
      end
    end

    context "with date range filter" do
      let(:start_date) { (Date.current - 7.days).to_s }
      let(:end_date) { Date.current.to_s }

      it "accepts date parameters" do
        get reports_path, params: { start_date: start_date, end_date: end_date }
        expect(response).to have_http_status(:success)
      end
    end

    context "with category filter" do
      it "accepts category_ids parameter" do
        get reports_path, params: { category_ids: [category.id] }
        expect(response).to have_http_status(:success)
      end
    end

    context "with account filter" do
      it "accepts account_ids parameter" do
        get reports_path, params: { account_ids: [account.id] }
        expect(response).to have_http_status(:success)
      end
    end

    context "with all filters combined" do
      it "accepts all filter parameters" do
        get reports_path, params: {
          start_date: (Date.current - 30.days).to_s,
          end_date: Date.current.to_s,
          category_ids: [category.id],
          account_ids: [account.id]
        }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "unauthenticated access" do
    before { sign_out user }

    it "redirects to login" do
      get reports_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end

