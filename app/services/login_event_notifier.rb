# frozen_string_literal: true

# Decides whether a newly recorded LoginEvent should trigger an email alert.
# Called as an after_create hook on LoginEvent.
class LoginEventNotifier
  FAILURE_THRESHOLD_PER_IP   = 10
  FAILURE_WINDOW             = 1.hour
  FAMILIAR_IP_LOOKBACK       = 90.days
  ALERT_DEDUPE_TTL           = 1.hour

  def self.call(event)
    return if Rails.env.test?

    new(event).deliver
  end

  def initialize(event)
    @event = event
  end

  def deliver
    return unless target_user

    notify_suspicious_failures if failure_like?
    notify_unfamiliar_success  if @event.event_type == "success"
  rescue => e
    Rails.logger.warn("[LoginEventNotifier] error: #{e.class}: #{e.message}")
  end

  private

  # Alerts target the registered account holder. If the failure event has no
  # user_id (unknown email attempted) we still notify the single registered user
  # — there's only one in this app.
  def target_user
    @target_user ||= @event.user || User.first
  end

  def failure_like?
    %w[failure lockout otp_failure throttle block].include?(@event.event_type)
  end

  def notify_suspicious_failures
    return if @event.ip.blank?

    count = LoginEvent
      .where(ip: @event.ip)
      .where(event_type: %w[failure lockout otp_failure throttle block])
      .within(FAILURE_WINDOW)
      .count

    return if count < FAILURE_THRESHOLD_PER_IP
    return unless first_time_in_window?(:failures, @event.ip)

    SecurityMailer
      .suspicious_failed_attempts(target_user, ip: @event.ip, count: count, window: FAILURE_WINDOW)
      .deliver_now
  end

  def notify_unfamiliar_success
    return if @event.ip.blank?

    previously_seen = LoginEvent
      .where(user_id: target_user.id, event_type: %w[success otp_success])
      .where("created_at < ?", @event.created_at)
      .where("created_at > ?", FAMILIAR_IP_LOOKBACK.ago)
      .where(ip: @event.ip)
      .exists?

    return if previously_seen
    return unless first_time_in_window?(:unfamiliar, @event.ip)

    SecurityMailer
      .unfamiliar_successful_login(target_user, @event)
      .deliver_now
  end

  # Cache-backed dedupe so a sustained attack doesn't flood the inbox. Per IP
  # per category per hour.
  def first_time_in_window?(category, ip)
    key = "login_event_notifier:#{category}:#{ip}:#{Time.current.to_i / ALERT_DEDUPE_TTL.to_i}"
    Rails.cache.write(key, true, expires_in: ALERT_DEDUPE_TTL, unless_exist: true)
  end
end
