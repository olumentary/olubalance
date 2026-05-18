# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TrustedDevices", type: :request do
  let(:user) { create(:user) }

  describe "GET /trusted_devices" do
    it "redirects to sign in when unauthenticated" do
      get trusted_devices_path
      expect(response).to redirect_to(new_user_session_path)
    end

    context "when authenticated" do
      let!(:active)  { create(:trusted_device, user: user, user_agent: "ActiveBrowser") }
      let!(:revoked) { create(:trusted_device, :revoked, user: user, user_agent: "RevokedBrowser") }
      let!(:expired) { create(:trusted_device, :expired, user: user, user_agent: "ExpiredBrowser") }

      before { sign_in user }

      it "lists only active devices" do
        get trusted_devices_path
        expect(response.body).to include("ActiveBrowser")
        expect(response.body).not_to include("RevokedBrowser")
        expect(response.body).not_to include("ExpiredBrowser")
      end
    end
  end

  describe "DELETE /trusted_devices/:id" do
    let!(:device) { create(:trusted_device, user: user) }
    before { sign_in user }

    it "revokes the device" do
      expect {
        delete trusted_device_path(device)
      }.to change { device.reload.revoked_at }.from(nil)
      expect(response).to redirect_to(trusted_devices_path)
    end

    it "scopes lookup to current_user" do
      other_device = create(:trusted_device)
      # current_user.trusted_devices.find raises RecordNotFound, which Rails
      # turns into a 404 response in request specs.
      delete trusted_device_path(other_device)
      expect(response).to have_http_status(:not_found)
      expect(other_device.reload.revoked_at).to be_nil
    end
  end

  describe "DELETE /trusted_devices/revoke_all" do
    before do
      create_list(:trusted_device, 3, user: user)
      sign_in user
    end

    it "revokes every active device for current_user" do
      delete revoke_all_trusted_devices_path
      expect(user.trusted_devices.active.count).to eq(0)
      expect(response).to redirect_to(trusted_devices_path)
    end

    it "deletes the trusted-device cookie" do
      delete revoke_all_trusted_devices_path
      expect(response.cookies[TrustedDevice::COOKIE_NAME.to_s]).to be_nil
    end
  end
end
