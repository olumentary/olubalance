# frozen_string_literal: true

class SecurityEventsController < ApplicationController
  include Pagy::Backend

  before_action :authenticate_user!

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
  end

  private

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
end
