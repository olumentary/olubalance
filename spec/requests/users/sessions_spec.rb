# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users::Sessions", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:password) { "topsecret" }
  let(:user)     { create(:user, password: password, password_confirmation: password) }

  def post_credentials(email: user.email, pwd: password, remember: "0")
    post user_session_path, params: { user: { email: email, password: pwd, remember_me: remember } }
  end

  describe "password step (no 2FA)" do
    it "signs the user in directly" do
      post_credentials
      # The post completes the sign-in; current_user is set in the response cycle.
      get authenticated_root_path
      expect(controller.current_user).to eq(user)
    end

    it "records a success login_event" do
      expect { post_credentials }.to change(LoginEvent.successes, :count).by(1)
      event = LoginEvent.recent.first
      expect(event).to have_attributes(event_type: "success", user_id: user.id)
    end

    it "records a failure on bad password and redirects back to sign-in" do
      expect {
        post_credentials(pwd: "wrong")
      }.to change(LoginEvent.failures, :count).by(1)
      expect(response).to redirect_to(new_user_session_path)
      expect(LoginEvent.recent.first.reason).to eq("invalid_password")
    end

    it "records a failure with no_such_user reason for unknown email" do
      post_credentials(email: "ghost@example.com", pwd: "anything")
      expect(LoginEvent.recent.first).to have_attributes(event_type: "failure", reason: "no_such_user", user_id: nil)
    end

    it "uses a generic flash message (no user enumeration)" do
      post_credentials(pwd: "wrong")
      follow_redirect!
      body = response.body
      expect(body).not_to include("not found")
      expect(body).not_to include("doesn't exist")
    end
  end

  describe "lockout flow" do
    it "locks the account after 8 failed attempts and records a lockout event" do
      7.times { post_credentials(pwd: "wrong") }
      expect {
        post_credentials(pwd: "wrong")
      }.to change(LoginEvent.where(event_type: "lockout"), :count).by(1)
      expect(user.reload.access_locked?).to be true
    end

    it "renders the lockout flash on a subsequent attempt" do
      8.times { post_credentials(pwd: "wrong") }
      post_credentials(pwd: password) # right password, but account is locked
      follow_redirect!
      expect(response.body).to include("temporarily locked")
    end
  end

  describe "2FA flow" do
    let(:user) { create(:user, :with_two_factor, password: password, password_confirmation: password) }

    it "redirects to the OTP challenge after a valid password" do
      post_credentials
      expect(response).to redirect_to(user_otp_challenge_path)
      expect(controller.current_user).to be_nil
    end

    it "renders the OTP form at the challenge URL" do
      post_credentials
      get user_otp_challenge_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Two-factor authentication")
    end

    it "rejects an invalid OTP code and records otp_failure" do
      post_credentials
      expect {
        post user_session_path, params: { otp_code: "000000" }
      }.to change(LoginEvent.where(event_type: "otp_failure"), :count).by(1)
      expect(response).to have_http_status(:unprocessable_content)
      expect(controller.current_user).to be_nil
    end

    it "signs in on a valid OTP code and records otp_success" do
      post_credentials
      code = user.current_otp
      expect {
        post user_session_path, params: { otp_code: code }
      }.to change(LoginEvent.where(event_type: "otp_success"), :count).by(1)
      follow_redirect!
      expect(controller.current_user).to eq(user)
    end

    it "issues a trusted device cookie when remember_device is checked" do
      post_credentials
      post user_session_path, params: { otp_code: user.current_otp, remember_device: "1" }
      expect(user.trusted_devices.active.count).to eq(1)
    end

    it "does not issue a trusted device when remember_device is unchecked" do
      post_credentials
      post user_session_path, params: { otp_code: user.current_otp }
      expect(user.trusted_devices.active.count).to eq(0)
    end

    it "expires the OTP-pending session after 5 minutes" do
      post_credentials
      travel 6.minutes do
        post user_session_path, params: { otp_code: user.current_otp }
        expect(response).to redirect_to(new_user_session_path)
        follow_redirect!
        expect(response.body).to include("expired")
      end
    end
  end

  describe "sign out" do
    before { sign_in user }

    it "ends the session on DELETE" do
      delete destroy_user_session_path
      get authenticated_root_path
      expect(controller.current_user).to be_nil
    end
  end
end
