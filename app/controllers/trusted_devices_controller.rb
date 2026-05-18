# frozen_string_literal: true

class TrustedDevicesController < ApplicationController
  before_action :authenticate_user!

  def index
    @devices = current_user.trusted_devices.active.order(last_seen_at: :desc)
  end

  def destroy
    device = current_user.trusted_devices.find(params[:id])
    device.revoke!
    flash[:notice] = "Device revoked."
    redirect_to trusted_devices_path
  end

  def revoke_all
    current_user.trusted_devices.active.update_all(revoked_at: Time.current)
    cookies.delete(TrustedDevice::COOKIE_NAME)
    flash[:notice] = "All trusted devices revoked. You'll be asked for a code on next sign-in."
    redirect_to trusted_devices_path
  end
end
