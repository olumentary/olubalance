# frozen_string_literal: true

# Dashboard for the 2FA feature. Lists enrolled authenticators, shows status,
# and manages backup codes. Authenticator enrollment / removal lives in
# `AuthenticatorsController` — this controller is purely a hub.
class TwoFactorSettingsController < ApplicationController
  before_action :authenticate_user!

  # GET /two_factor_settings
  def show
    @authenticators            = current_user.authenticators.confirmed.recent_first
    @enabled                   = @authenticators.any?
    @has_backup_codes          = current_user.otp_backup_codes.present?
    # Set by AuthenticatorsController#create (first enrollment) or by the HTML
    # fallback for regenerate_backup_codes — surfaces the codes once via modal.
    @just_generated_backup_codes = flash[:backup_codes_just_generated]
  end

  # POST /two_factor_settings/regenerate_backup_codes
  # Turbo Stream response: injects a modal listing the new codes into the
  # `backup_codes_modal` placeholder on the dashboard. HTML fallback renders
  # the full-page view (used by specs and JS-off browsers).
  def regenerate_backup_codes
    if current_user.authenticators.confirmed.none?
      flash[:alert] = "Enroll an authenticator before generating backup codes."
      return redirect_to two_factor_settings_path
    end

    @backup_codes = current_user.generate_otp_backup_codes!
    current_user.save!

    respond_to do |format|
      format.turbo_stream # renders regenerate_backup_codes.turbo_stream.erb
      format.html do
        flash[:backup_codes_just_generated] = @backup_codes
        redirect_to two_factor_settings_path,
                    notice: "New backup codes generated. Previous codes are no longer valid."
      end
    end
  end

  # DELETE /two_factor_settings — disable 2FA entirely (clears authenticators,
  # backup codes, trusted devices). Requires the current password as confirmation.
  def destroy
    if current_user.valid_password?(params[:current_password].to_s)
      current_user.disable_two_factor!
      cookies.delete(TrustedDevice::COOKIE_NAME)
      session.delete(:pending_authenticator_secret)
      flash[:notice] = "Two-factor authentication disabled."
    else
      flash[:alert] = "Password was incorrect; 2FA was not changed."
    end
    redirect_to two_factor_settings_path
  end
end
