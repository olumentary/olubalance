# frozen_string_literal: true

# Manages enrollment, disabling, and backup code regeneration for the current
# user's TOTP authenticator. Mounted as a singular resource so the URL space is
# `/two_factor_settings`.
class TwoFactorSettingsController < ApplicationController
  before_action :authenticate_user!

  # GET /two_factor_settings
  # Enrollment landing: shows QR + secret for unenrolled users, status + backup
  # code regeneration for enrolled users.
  def show
    if current_user.two_factor_enabled?
      @enrolled = true
    else
      @enrolled = false
      @pending_secret = pending_secret
      @provisioning_uri = User.new(email: current_user.email)
        .tap { |u| u.otp_secret = @pending_secret }
        .otp_provisioning_uri(current_user.email, issuer: "olubalance")
      @qr_svg = RQRCode::QRCode.new(@provisioning_uri).as_svg(
        offset: 0, color: "000",
        shape_rendering: "crispEdges",
        module_size: 4, standalone: true
      ).html_safe
    end
  end

  # POST /two_factor_settings
  # Verifies the first OTP code, persists the secret, generates backup codes.
  def create
    secret = session[:pending_otp_secret]
    code   = params[:otp_code].to_s.gsub(/\s+/, "")

    if secret.blank? || code.blank?
      flash[:alert] = "Missing code. Please start over."
      return redirect_to two_factor_settings_path
    end

    # Temporarily assign the candidate secret so validate_and_consume_otp! works.
    current_user.otp_secret = secret
    if current_user.validate_and_consume_otp!(code)
      current_user.otp_required_for_login = true
      @backup_codes = current_user.generate_otp_backup_codes!
      current_user.save!
      session.delete(:pending_otp_secret)
      flash[:notice] = "Two-factor authentication enabled. Save your backup codes below."
      render :backup_codes
    else
      flash[:alert] = "That code didn't match. Try again."
      redirect_to two_factor_settings_path
    end
  end

  # DELETE /two_factor_settings
  # Disables 2FA. Requires the current password as confirmation.
  def destroy
    if current_user.valid_password?(params[:current_password].to_s)
      current_user.disable_two_factor!
      session.delete(:pending_otp_secret)
      flash[:notice] = "Two-factor authentication disabled."
    else
      flash[:alert] = "Password was incorrect; 2FA was not changed."
    end
    redirect_to two_factor_settings_path
  end

  # POST /two_factor_settings/regenerate_backup_codes
  def regenerate_backup_codes
    @backup_codes = current_user.generate_otp_backup_codes!
    current_user.save!
    flash[:notice] = "New backup codes generated. Old codes are no longer valid."
    render :backup_codes
  end

  # GET /two_factor_settings/backup_codes — re-renders nothing (codes are shown
  # only once after generation). Redirects to show.
  def backup_codes
    redirect_to two_factor_settings_path
  end

  private

  # The candidate secret lives in the session until the user confirms a code,
  # so refreshing the QR page doesn't regenerate the secret on every view.
  def pending_secret
    session[:pending_otp_secret] ||= User.generate_otp_secret
  end
end
