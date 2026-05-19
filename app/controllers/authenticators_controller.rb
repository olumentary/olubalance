# frozen_string_literal: true

# Manages individual TOTP authenticators (one per enrolled phone/device).
# Multiple authenticators per user allow shared accounts (e.g. household)
# without sharing a secret.
class AuthenticatorsController < ApplicationController
  before_action :authenticate_user!

  # GET /authenticators/new — render QR + nickname form. Secret persists in
  # session across reloads so refreshing the page doesn't regenerate.
  def new
    @nickname         = params[:nickname].to_s
    @pending_secret   = session[:pending_authenticator_secret] ||= Authenticator.generate_secret
    @provisioning_uri = Authenticator.provisioning_uri(
      secret:  @pending_secret,
      account: provisioning_account_label
    )
    @qr_svg = RQRCode::QRCode.new(@provisioning_uri).as_svg(
      offset: 0, color: "000",
      shape_rendering: "crispEdges",
      module_size: 4, standalone: true
    ).html_safe
  end

  # POST /authenticators — verify the submitted code against the pending
  # secret, then persist the authenticator. If this is the user's first
  # authenticator, also issue backup codes (returned to the caller via
  # session so the dashboard can display them).
  def create
    secret   = session[:pending_authenticator_secret]
    nickname = params[:nickname].to_s.strip
    code     = params[:otp_code].to_s.gsub(/\s+/, "")

    if secret.blank?
      flash[:alert] = "Enrollment session expired. Please start again."
      return redirect_to new_authenticator_path
    end

    auth = current_user.authenticators.build(
      nickname:     nickname.presence || default_nickname,
      otp_secret:   secret,
      confirmed_at: Time.current
    )

    unless auth.valid?
      flash[:alert] = auth.errors.full_messages.to_sentence
      return redirect_to new_authenticator_path(nickname: nickname)
    end

    unless ROTP::TOTP.new(secret).verify(code, drift_behind: Authenticator::DRIFT, drift_ahead: Authenticator::DRIFT)
      flash[:alert] = "That code didn't match. Try again."
      return redirect_to new_authenticator_path(nickname: nickname)
    end

    issued_backup_codes = nil
    ActiveRecord::Base.transaction do
      auth.save!
      if current_user.otp_backup_codes.blank?
        issued_backup_codes = current_user.generate_otp_backup_codes!
        current_user.save!
      end
    end

    session.delete(:pending_authenticator_secret)

    # Always end on the settings dashboard. If this was the first enrollment,
    # ride-along the backup codes via flash so the dashboard can pop the modal.
    if issued_backup_codes
      flash[:backup_codes_just_generated] = issued_backup_codes
      flash[:notice] = "#{auth.nickname} added. Save your backup codes below."
    else
      flash[:notice] = "#{auth.nickname} added."
    end
    redirect_to two_factor_settings_path
  end

  # DELETE /authenticators/:id — revoke a single authenticator. Removing the
  # last one disables 2FA entirely (clears backup codes + revokes trusted
  # devices).
  def destroy
    auth = current_user.authenticators.find(params[:id])
    auth.destroy!

    if current_user.authenticators.confirmed.none?
      current_user.update!(otp_backup_codes: [])
      current_user.trusted_devices.update_all(revoked_at: Time.current)
      cookies.delete(TrustedDevice::COOKIE_NAME)
      flash[:notice] = "#{auth.nickname} removed. Two-factor authentication is now off."
    else
      flash[:notice] = "#{auth.nickname} removed."
    end

    redirect_to two_factor_settings_path
  end

  private

  # Authenticator apps display labels like "olubalance:kevin@example.com" — if
  # the user has multiple confirmed authenticators, suffix with the nickname so
  # they can tell entries apart inside the app.
  def provisioning_account_label
    if current_user.authenticators.confirmed.any?
      "#{current_user.email} (#{Time.current.strftime('%b %-d')})"
    else
      current_user.email
    end
  end

  def default_nickname
    "Device #{current_user.authenticators.count + 1}"
  end
end
