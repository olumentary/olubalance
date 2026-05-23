# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /accounts/:id/mark_reviewed_this_week", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let!(:account) do
    a = create(:account, user: user)
    a.update_columns(last_transaction_on: 30.days.ago.to_date)
    a
  end

  before { sign_in user }

  it "stamps last_transaction_on to today" do
    post mark_reviewed_this_week_account_path(account)
    expect(account.reload.last_transaction_on).to eq(Date.current)
  end

  it "responds with a turbo_stream" do
    post mark_reviewed_this_week_account_path(account),
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include("account_card_#{account.id}")
    expect(response.body).to include("weekly_banner")
  end

  it "redirects on HTML" do
    post mark_reviewed_this_week_account_path(account)
    expect(response).to redirect_to(accounts_path)
  end

  it "is scoped to current_user — cannot mark another user's account" do
    foreign = create(:account, user: other_user)
    foreign.update_columns(last_transaction_on: 30.days.ago.to_date)
    post mark_reviewed_this_week_account_path(foreign)
    expect(response).to have_http_status(:not_found)
    expect(foreign.reload.last_transaction_on).to eq(30.days.ago.to_date)
  end
end
