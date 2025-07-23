# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :set_timezone
  before_action :assign_navbar_content
  before_action :configure_permitted_parameters, if: :devise_controller?

  def current_user
    UserDecorator.decorate(super) unless super.nil?
  end

  def assign_navbar_content
    @navbar_accounts = current_user.accounts if user_signed_in?
  end

  # Helper method to detect mobile devices
  def mobile_device?
    request.user_agent =~ /Mobile|Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i
  end

  helper_method :mobile_device?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up) \
      { |u| u.permit(:first_name, :last_name, :timezone, :email, :password, :password_confirmation) }
    devise_parameter_sanitizer.permit(:account_update) \
      { |u| u.permit(:first_name, :last_name, :timezone, :email, :password, :current_password, :password_confirmation) }
  end

  private

  def set_timezone
    tz = current_user ? current_user.timezone : nil
    Time.zone = tz || ActiveSupport::TimeZone["UTC"]
  end
end
