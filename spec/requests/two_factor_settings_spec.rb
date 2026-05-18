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

    context "when not yet enrolled" do
      before { sign_in user }

      it "renders the enrollment view with a QR + secret" do
        get two_factor_settings_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Enroll an authenticator app")
        expect(response.body).to include("<svg")
      end

      it "persists the candidate secret in session across reloads" do
        get two_factor_settings_path
        first_secret = session[:pending_otp_secret]
        expect(first_secret).to be_present

        get two_factor_settings_path
        expect(session[:pending_otp_secret]).to eq(first_secret)
      end
    end

    context "when already enrolled" do
      before do
        user.update!(otp_secret: User.generate_otp_secret, otp_required_for_login: true)
        sign_in user
      end

      it "renders the enrolled view with disable + regenerate options" do
        get two_factor_settings_path
        expect(response.body).to include("2FA is enabled")
        expect(response.body).to include("Disable two-factor authentication")
        expect(response.body).to include("Regenerate backup codes")
      end
    end
  end

  describe "POST /two_factor_settings" do
    before { sign_in user }

    it "enables 2FA + issues backup codes when the OTP is valid" do
      get two_factor_settings_path # seeds session[:pending_otp_secret]
      secret = session[:pending_otp_secret]
      totp   = ROTP::TOTP.new(secret)

      expect {
        post two_factor_settings_path, params: { otp_code: totp.now }
      }.to change { user.reload.otp_required_for_login }.from(false).to(true)

      expect(response.body).to include("Backup codes")
      # The page should show all 10 codes
      expect(user.reload.otp_backup_codes.size).to eq(10)
    end

    it "rejects an invalid OTP and does not enable 2FA" do
      get two_factor_settings_path
      post two_factor_settings_path, params: { otp_code: "000000" }
      expect(response).to redirect_to(two_factor_settings_path)
      expect(user.reload.otp_required_for_login).to be false
    end
  end

  describe "DELETE /two_factor_settings" do
    before do
      user.update!(otp_secret: User.generate_otp_secret, otp_required_for_login: true)
      user.generate_otp_backup_codes!
      user.save!
      create(:trusted_device, user: user)
      sign_in user
    end

    it "disables 2FA and revokes all trusted devices when the password is right" do
      expect {
        delete two_factor_settings_path, params: { current_password: password }
      }.to change { user.reload.otp_required_for_login }.from(true).to(false)

      expect(user.trusted_devices.active.count).to eq(0)
      expect(user.otp_secret).to be_nil
      expect(user.otp_backup_codes).to eq([])
    end

    it "leaves 2FA enabled when the password is wrong" do
      delete two_factor_settings_path, params: { current_password: "nope" }
      expect(user.reload.otp_required_for_login).to be true
      expect(user.trusted_devices.active.count).to eq(1)
    end
  end

  describe "POST /two_factor_settings/regenerate_backup_codes" do
    before do
      user.update!(otp_secret: User.generate_otp_secret, otp_required_for_login: true)
      user.generate_otp_backup_codes!
      user.save!
      sign_in user
    end

    it "rotates the backup codes" do
      old_codes = user.otp_backup_codes.dup
      post regenerate_backup_codes_two_factor_settings_path
      expect(user.reload.otp_backup_codes).not_to eq(old_codes)
      expect(user.otp_backup_codes.size).to eq(10)
    end
  end
end
