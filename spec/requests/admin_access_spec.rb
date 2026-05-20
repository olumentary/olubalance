# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Motor Admin access gate", type: :request do
  it "redirects unauthenticated requests to sign-in" do
    get "/db_admin"
    expect(response).to have_http_status(:found)
    expect(response.location).to end_with("/users/sign_in")
  end

  it "404s for signed-in non-admin users" do
    sign_in create(:user)
    get "/db_admin"
    expect(response).to have_http_status(:not_found)
  end

  it "lets admins through" do
    sign_in create(:user, :admin)
    get "/db_admin"
    expect(response.status).to be_between(200, 399)
  end
end
