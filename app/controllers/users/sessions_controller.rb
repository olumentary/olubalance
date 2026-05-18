# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  OTP_PENDING_TTL = 5.minutes

  # ApplicationController before_actions touch `current_user`, which on a fresh
  # POST with sign-in params triggers Warden's authentication strategies and
  # increments `failed_attempts` once per strategy in the chain — locking the
  # account after ~3 wrong tries instead of 8. Skip them on `create`; our own
  # flow decides everything from `params[:user]` directly.
  skip_before_action :set_timezone, only: :create
  skip_before_action :assign_navbar_content, only: :create

  # POST /users/sign_in — same endpoint handles both the password step and the
  # OTP step; the latter is identified by the presence of `otp_code` plus an
  # OTP-pending session set during the password step.
  def create
    if params[:otp_code].present? || session[:otp_pending_user_id].present?
      handle_otp_submission
    else
      authenticate_with_password
    end
  end

  # GET /users/otp — renders the OTP challenge form when a password-validated
  # user is mid-flow.
  def otp_challenge
    unless otp_session_active?
      clear_otp_pending
      return redirect_to new_user_session_path
    end

    @user = User.find(session[:otp_pending_user_id])
  end

  private

  def handle_otp_submission
    unless otp_session_active?
      clear_otp_pending
      redirect_to new_user_session_path, alert: "Your sign-in session expired. Please try again."
      return
    end

    verify_otp
  end

  def otp_session_active?
    return false if session[:otp_pending_user_id].blank?

    started_at = session[:otp_pending_at].to_i
    started_at >= OTP_PENDING_TTL.ago.to_i
  end

  def authenticate_with_password
    email    = params.dig(:user, :email).to_s.strip.downcase
    password = params.dig(:user, :password).to_s
    user     = User.find_by(email: email)

    was_locked_before = user&.access_locked?
    # `valid_for_authentication?` returns `:locked` (truthy) when it has just
    # locked the account, and `true` only on a clean success. Treat anything
    # other than literal `true` (plus an active-auth check) as failure.
    raw_result = user&.valid_for_authentication? { user.valid_password?(password) }
    auth_ok    = raw_result == true && user.active_for_authentication?

    unless auth_ok
      record_failure(user: user, email: email, reason: failure_reason_for(user, was_locked_before))
      flash[:alert] = if user&.access_locked?
        "Your account is temporarily locked. Try again in 30 minutes."
      else
        I18n.t("devise.failure.invalid", authentication_keys: "Email")
      end
      redirect_to new_user_session_path
      return
    end

    LoginEvent.record_password_attempt(request: request, email: email, user: user, success: true)

    if user.otp_required_for_login? && !trusted_device_for?(user)
      session[:otp_pending_user_id]     = user.id
      session[:otp_pending_remember_me] = remember_me_requested?
      session[:otp_pending_at]          = Time.current.to_i
      redirect_to user_otp_challenge_path
    else
      complete_sign_in(user, remember: remember_me_requested?)
    end
  end

  def failure_reason_for(user, was_locked_before)
    return "no_such_user"      if user.nil?
    return "already_locked"    if was_locked_before
    return "just_locked"       if user.access_locked?
    return "unconfirmed"       unless user.confirmed?

    "invalid_password"
  end

  def record_failure(user:, email:, reason:)
    LoginEvent.record_password_attempt(
      request: request,
      email:   email,
      user:    user,
      success: false,
      reason:  reason
    )
    if reason == "just_locked" && user
      LoginEvent.record_lockout(user: user, ip: request.remote_ip, user_agent: request.user_agent)
    end
  end

  def verify_otp
    user = User.find(session[:otp_pending_user_id])
    code = params[:otp_code].to_s.gsub(/\s+/, "")

    success =
      if user.invalidate_otp_backup_code!(code)
        user.save!
        true
      else
        user.validate_and_consume_otp!(code)
      end

    if success
      LoginEvent.record_otp(request: request, user: user, success: true)
      issue_trusted_device(user) if params[:remember_device] == "1"
      remember = session[:otp_pending_remember_me]
      clear_otp_pending
      complete_sign_in(user, remember: remember)
    else
      LoginEvent.record_otp(request: request, user: user, success: false, reason: "invalid_code")
      @user = user
      flash.now[:alert] = "Invalid verification code."
      render :otp_challenge, status: :unprocessable_content
    end
  end

  def complete_sign_in(user, remember:)
    user.remember_me = true if remember
    sign_in(user)
    redirect_to after_sign_in_path_for(user)
  end

  def remember_me_requested?
    value = params.dig(:user, :remember_me)
    return true if mobile_device?

    %w[1 true on yes].include?(value.to_s)
  end

  def clear_otp_pending
    session.delete(:otp_pending_user_id)
    session.delete(:otp_pending_remember_me)
    session.delete(:otp_pending_at)
  end

  def trusted_device_for?(user)
    cookie = cookies.signed[TrustedDevice::COOKIE_NAME]
    return false unless cookie.is_a?(Hash)
    return false unless cookie["user_id"].to_i == user.id || cookie[:user_id].to_i == user.id

    token  = cookie["token"] || cookie[:token]
    device = TrustedDevice.lookup(user: user, token: token)
    return false unless device

    device.touch_last_seen!(ip: request.remote_ip)
    true
  end

  def issue_trusted_device(user)
    token = TrustedDevice.issue!(user: user, user_agent: request.user_agent, ip: request.remote_ip)
    cookies.signed[TrustedDevice::COOKIE_NAME] = {
      value:     { user_id: user.id, token: token },
      expires:   TrustedDevice.remember_days.days.from_now,
      secure:    Rails.env.production? || Rails.env.staging?,
      httponly:  true,
      same_site: :lax
    }
  end
end
