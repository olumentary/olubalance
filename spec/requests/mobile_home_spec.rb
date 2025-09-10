require 'rails_helper'

RSpec.describe "Mobile Home", type: :request do
  let(:user) { FactoryBot.create(:user) }

  before do
    sign_in user
  end

  describe "GET /" do
    context "when user is on mobile device" do
      before do
        allow_any_instance_of(ApplicationController).to receive(:mobile_device?).and_return(true)
      end

      it "redirects to mobile home page" do
        get root_path
        expect(response).to redirect_to(mobile_home_path)
      end
    end

    context "when user is on desktop device" do
      before do
        allow_any_instance_of(ApplicationController).to receive(:mobile_device?).and_return(false)
      end

      it "redirects to accounts page" do
        get root_path
        expect(response).to redirect_to(accounts_path)
      end
    end
  end

  describe "GET /mobile_home" do
    it "returns success" do
      get mobile_home_path
      expect(response).to have_http_status(:success)
    end

    it "renders mobile home template" do
      get mobile_home_path
      expect(response).to render_template(:mobile_home)
    end

    context "when user is not authenticated" do
      before do
        sign_out user
      end

      it "redirects to login page" do
        get mobile_home_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end 