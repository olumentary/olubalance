# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TwoFactorSettings", type: :request do
  let(:password) { "topsecret" }
  let(:user)     { create(:user, password: password, password_confirmation: password) }

  describe "GET /two_factor_settings" do
    it "redirects to sign in when unauthenticated" do
      get two_factor_settings_path
      expect(response).to redirect_to(new_user_session_path)
    end

    context "no authenticators enrolled" do
      before { sign_in user }

      it "renders the dashboard with the disabled state and add button" do
        get two_factor_settings_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("2FA disabled")
        expect(response.body).to include("Add a new authenticator")
        expect(response.body).to include("haven't enrolled any authenticators")
      end

      it "hides backup-code and disable-2FA controls" do
        get two_factor_settings_path
        expect(response.body).not_to include("Regenerate backup codes")
        expect(response.body).not_to include("Disable two-factor authentication")
      end
    end

    context "with one authenticator enrolled" do
      let!(:user) { create(:user, :with_two_factor, password: password, password_confirmation: password) }
      before { sign_in user }

      it "lists the authenticator and surfaces the disable form" do
        get two_factor_settings_path
        expect(response.body).to include("2FA enabled")
        expect(response.body).to include("Test Phone")
        expect(response.body).to include("Regenerate backup codes")
        expect(response.body).to include("Disable two-factor authentication")
      end
    end
  end

  describe "DELETE /two_factor_settings" do
    let!(:user) { create(:user, :with_two_factor, password: password, password_confirmation: password) }
    before do
      user.generate_otp_backup_codes!
      user.save!
      create(:trusted_device, user: user)
      sign_in user
    end

    it "wipes everything when the password matches" do
      expect {
        delete two_factor_settings_path, params: { current_password: password }
      }.to change { user.reload.authenticators.count }.to(0)
      expect(user.otp_backup_codes).to eq([])
      expect(user.trusted_devices.active.count).to eq(0)
    end

    it "leaves 2FA intact on wrong password" do
      delete two_factor_settings_path, params: { current_password: "nope" }
      expect(user.reload.authenticators.count).to eq(1)
    end
  end

  describe "POST /two_factor_settings/regenerate_backup_codes" do
    context "with at least one authenticator" do
      let!(:user) { create(:user, :with_two_factor) }
      before do
        user.generate_otp_backup_codes!
        user.save!
        sign_in user
      end

      it "rotates the codes and redirects to settings with codes on a one-shot flash" do
        old = user.otp_backup_codes.dup
        post regenerate_backup_codes_two_factor_settings_path
        expect(user.reload.otp_backup_codes).not_to eq(old)
        expect(user.otp_backup_codes.size).to eq(10)
        expect(response).to redirect_to(two_factor_settings_path)
        follow_redirect!
        expect(response.body).to include("Save your backup codes")
      end

      it "responds to turbo_stream by updating the modal container" do
        post regenerate_backup_codes_two_factor_settings_path,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("backup_codes_modal_container")
        expect(response.body).to include("backup-codes-modal")
      end
    end

    context "without authenticators" do
      before { sign_in user }

      it "refuses and redirects with an alert" do
        post regenerate_backup_codes_two_factor_settings_path
        expect(response).to redirect_to(two_factor_settings_path)
        follow_redirect!
        expect(response.body).to include("Enroll an authenticator")
      end
    end
  end
end
