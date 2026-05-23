# frozen_string_literal: true

class SecurityEventsController < ApplicationController
  include Pagy::Backend

  before_action :authenticate_user!
  before_action :require_admin, only: %i[unlock_account unlock_ip]

  FILTER_TYPES = LoginEvent::EVENT_TYPES + [ "all", "failures", "successes" ]
  DEFAULT_WINDOW_DAYS = 30

  def index
    scope = LoginEvent.recent
    scope = apply_event_type_filter(scope, params[:event_type])
    scope = apply_window_filter(scope, params[:days])
    scope = scope.where(ip: params[:ip])                              if params[:ip].present?
    scope = scope.where("email_attempted ILIKE ?", "%#{params[:q]}%") if params[:q].present?

    @pagy, @events = pagy(scope, items: 50)
    @summary = build_summary
    @trusted_devices_count = current_user.trusted_devices.active.count
    @locked_users, @blocked_ips = load_active_locks
  end

  # POST /security_events/unlock_account
  # Admin-only. Clears Devise lock state for the target user after verifying
  # the admin's current password.
  def unlock_account
    user = User.find(params[:user_id])

    unless current_user.valid_password?(params[:current_password].to_s)
      flash[:alert] = "Password was incorrect; no changes made."
      return redirect_to security_events_path
    end

    AuthLockManager.unlock_user!(user)
    LoginEvent.record_unlock(
      actor:       current_user,
      target_user: user,
      reason:      "admin_account_unlock",
      request:     request
    )
    flash[:notice] = "Account for #{user.email} has been unlocked."
    redirect_to security_events_path
  end

  # POST /security_events/unlock_ip
  # Admin-only. Clears Rack::Attack throttle counters + fail2ban block for the
  # given IP after verifying the admin's current password.
  def unlock_ip
    ip = params[:ip].to_s.strip

    if ip.blank?
      flash[:alert] = "No IP provided."
      return redirect_to security_events_path
    end

    unless current_user.valid_password?(params[:current_password].to_s)
      flash[:alert] = "Password was incorrect; no changes made."
      return redirect_to security_events_path
    end

    AuthLockManager.clear_ip!(ip)
    LoginEvent.record_unlock(
      actor:   current_user,
      ip:      ip,
      reason:  "admin_ip_unlock",
      request: request
    )
    flash[:notice] = "Throttle and block for IP #{ip} cleared."
    redirect_to security_events_path
  end

  private

  def require_admin
    head :not_found unless current_user&.admin?
  end

  def apply_event_type_filter(scope, type)
    case type
    when nil, "", "all"
      scope
    when "failures"
      scope.failures
    when "successes"
      scope.successes
    when *LoginEvent::EVENT_TYPES
      scope.where(event_type: type)
    else
      scope
    end
  end

  def apply_window_filter(scope, days_param)
    days = (days_param.presence || DEFAULT_WINDOW_DAYS).to_i.clamp(1, 365)
    scope.within(days.days)
  end

  def build_summary
    last_24h = LoginEvent.within(24.hours)
    {
      failures_24h:  last_24h.failures.count,
      successes_24h: last_24h.successes.count,
      throttles_24h: last_24h.where(event_type: "throttle").count,
      blocks_24h:    last_24h.where(event_type: "block").count,
      unique_ips_24h: last_24h.distinct.count(:ip)
    }
  end

  # Admin-only data for the "Active locks" panel.
  def load_active_locks
    return [ [], [] ] unless current_user&.admin?

    locked = User.where.not(locked_at: nil).order(locked_at: :desc)
    blocked = LoginEvent
              .within(24.hours)
              .where(event_type: %w[throttle block])
              .where.not(ip: nil)
              .group(:ip)
              .order(Arel.sql("MAX(created_at) DESC"))
              .pluck(:ip, Arel.sql("COUNT(*)"), Arel.sql("MAX(created_at)"))

    [ locked, blocked ]
  end
end
