# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Authenticators", type: :request do
  let(:password) { "topsecret" }
  let(:user)     { create(:user, password: password, password_confirmation: password) }

  describe "GET /authenticators/new" do
    it "redirects to sign in when unauthenticated" do
      get new_authenticator_path
      expect(response).to redirect_to(new_user_session_path)
    end

    context "when authenticated" do
      before { sign_in user }

      it "renders the enrollment form with a QR + secret" do
        get new_authenticator_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Add a new authenticator")
        expect(response.body).to include("<svg")
      end

      it "persists the pending secret across reloads" do
        get new_authenticator_path
        first = session[:pending_authenticator_secret]
        expect(first).to be_present
        get new_authenticator_path
        expect(session[:pending_authenticator_secret]).to eq(first)
      end
    end
  end

  describe "POST /authenticators" do
    before { sign_in user }

    def valid_code_for(secret)
      ROTP::TOTP.new(secret).now
    end

    context "with a valid code (first enrollment)" do
      it "persists the authenticator and issues backup codes" do
        get new_authenticator_path
        secret = session[:pending_authenticator_secret]

        expect {
          post authenticators_path,
               params: { nickname: "Kevin's phone", otp_code: valid_code_for(secret) }
        }.to change { user.reload.authenticators.count }.from(0).to(1)

        expect(user.authenticators.first.nickname).to eq("Kevin's phone")
        expect(response).to redirect_to(two_factor_settings_path)
        expect(user.reload.otp_backup_codes.size).to eq(10)
      end

      it "surfaces the backup-codes modal on the next page render" do
        get new_authenticator_path
        secret = session[:pending_authenticator_secret]
        post authenticators_path,
             params: { nickname: "Kevin's phone", otp_code: valid_code_for(secret) }
        follow_redirect!
        expect(response.body).to include("Save your backup codes")
        expect(response.body).to include("backup-codes-modal")
      end
    end

    context "with a valid code (second enrollment)" do
      let!(:user) { create(:user, :with_two_factor, password: password, password_confirmation: password) }
      before do
        user.generate_otp_backup_codes!
        user.save!
        sign_in user
      end

      it "adds a second authenticator without regenerating backup codes" do
        get new_authenticator_path
        secret = session[:pending_authenticator_secret]
        old_codes = user.otp_backup_codes.dup

        post authenticators_path,
             params: { nickname: "Wife's phone", otp_code: valid_code_for(secret) }

        expect(user.reload.authenticators.pluck(:nickname)).to contain_exactly("Test Phone", "Wife's phone")
        expect(user.otp_backup_codes).to eq(old_codes)
        expect(response).to redirect_to(two_factor_settings_path)
      end
    end

    it "rejects an invalid code" do
      get new_authenticator_path
      expect {
        post authenticators_path,
             params: { nickname: "Bad", otp_code: "000000" }
      }.not_to change { user.authenticators.count }
      follow_redirect!
      expect(response.body).to include("Try again")
    end

    it "rejects a duplicate nickname" do
      create(:authenticator, user: user, nickname: "Phone")
      get new_authenticator_path
      secret = session[:pending_authenticator_secret]
      expect {
        post authenticators_path,
             params: { nickname: "Phone", otp_code: valid_code_for(secret) }
      }.not_to change { user.authenticators.count }
    end

    it "starts over cleanly if the pending secret is gone" do
      # No GET /authenticators/new — so session[:pending_authenticator_secret] is nil
      post authenticators_path, params: { nickname: "X", otp_code: "123456" }
      expect(response).to redirect_to(new_authenticator_path)
    end
  end

  describe "DELETE /authenticators/:id" do
    let!(:user) { create(:user, :with_two_factor, password: password, password_confirmation: password) }
    let(:auth)  { user.authenticators.first }

    before do
      user.generate_otp_backup_codes!
      user.save!
      create(:trusted_device, user: user)
      sign_in user
    end

    it "removes the authenticator and disables 2FA when it's the last one" do
      delete authenticator_path(auth)
      user.reload
      expect(user.authenticators.confirmed.count).to eq(0)
      expect(user.otp_backup_codes).to eq([])
      expect(user.trusted_devices.active.count).to eq(0)
    end

    it "keeps 2FA enabled when other authenticators remain" do
      other = create(:authenticator, user: user, nickname: "Other phone")
      delete authenticator_path(auth)
      expect(user.reload.authenticators.confirmed).to contain_exactly(other)
      expect(user.otp_backup_codes).not_to be_empty
    end

    it "scopes lookup to current_user" do
      foreign = create(:authenticator)
      delete authenticator_path(foreign)
      expect(response).to have_http_status(:not_found)
      expect(Authenticator.exists?(foreign.id)).to be true
    end
  end
end
