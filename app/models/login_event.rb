# frozen_string_literal: true

# Append-only record of authentication-related events: password successes,
# failures, lockouts, OTP outcomes, and Rack::Attack throttles/blocks.
# Used by the monitoring UI and email alerts.
class LoginEvent < ApplicationRecord
  belongs_to :user, optional: true

  EVENT_TYPES = %w[
    success
    failure
    lockout
    throttle
    block
    otp_success
    otp_failure
    unlock
  ].freeze

  validates :event_type, inclusion: { in: EVENT_TYPES }

  after_create_commit :notify

  scope :recent, -> { order(created_at: :desc) }
  scope :failures, -> { where(event_type: %w[failure lockout otp_failure]) }
  scope :successes, -> { where(event_type: %w[success otp_success]) }
  scope :within, ->(window) { where("created_at > ?", window.ago) }

  # Records a failure or success from a Warden hook.
  def self.record_password_attempt(request:, email:, user:, success:, reason: nil)
    create!(
      user:            user,
      email_attempted: email.to_s.downcase.strip.presence,
      ip:              request&.remote_ip,
      user_agent:      request&.user_agent.to_s.first(255),
      event_type:      success ? "success" : "failure",
      reason:          reason
    )
  rescue ActiveRecord::RecordInvalid, ActiveRecord::ConnectionNotEstablished => e
    Rails.logger.warn("[LoginEvent] failed to record: #{e.class}: #{e.message}")
    nil
  end

  # Records an OTP attempt outcome from the sessions controller.
  def self.record_otp(request:, user:, success:, reason: nil)
    create!(
      user:            user,
      email_attempted: user&.email,
      ip:              request&.remote_ip,
      user_agent:      request&.user_agent.to_s.first(255),
      event_type:      success ? "otp_success" : "otp_failure",
      reason:          reason
    )
  rescue ActiveRecord::RecordInvalid, ActiveRecord::ConnectionNotEstablished => e
    Rails.logger.warn("[LoginEvent] failed to record: #{e.class}: #{e.message}")
    nil
  end

  # Records a Rack::Attack throttle or block event.
  def self.record_rack_attack(request:, event_type:)
    return unless EVENT_TYPES.include?(event_type.to_s)

    email = nil
    if request.params.is_a?(Hash) && request.params["user"].is_a?(Hash)
      email = request.params["user"]["email"].to_s.downcase.strip.presence
    end

    create!(
      email_attempted: email,
      ip:              request.ip,
      user_agent:      request.user_agent.to_s.first(255),
      event_type:      event_type.to_s,
      reason:          request.env["rack.attack.matched"].to_s,
      metadata:        { path: request.path }
    )
  rescue ActiveRecord::RecordInvalid, ActiveRecord::ConnectionNotEstablished => e
    Rails.logger.warn("[LoginEvent] failed to record rack-attack event: #{e.class}: #{e.message}")
    nil
  end

  # Records an admin-initiated unlock action (clears a Devise account lock or
  # a Rack::Attack throttle/block for an IP). `target_user` is set when a user
  # account was unlocked; `ip` is set when an IP block/throttle was cleared.
  def self.record_unlock(actor:, reason:, target_user: nil, ip: nil, request: nil)
    create!(
      user:            target_user,
      email_attempted: target_user&.email,
      ip:              ip || request&.remote_ip,
      user_agent:      request&.user_agent.to_s.first(255),
      event_type:      "unlock",
      reason:          reason,
      metadata:        { actor_id: actor&.id, actor_email: actor&.email }
    )
  rescue ActiveRecord::RecordInvalid, ActiveRecord::ConnectionNotEstablished => e
    Rails.logger.warn("[LoginEvent] failed to record unlock: #{e.class}: #{e.message}")
    nil
  end

  # Records an account lockout (called from after_failure when the user just
  # crossed the failed_attempts threshold).
  def self.record_lockout(user:, ip:, user_agent:)
    create!(
      user:            user,
      email_attempted: user.email,
      ip:              ip,
      user_agent:      user_agent.to_s.first(255),
      event_type:      "lockout",
      reason:          "max_failed_attempts"
    )
  rescue ActiveRecord::RecordInvalid, ActiveRecord::ConnectionNotEstablished => e
    Rails.logger.warn("[LoginEvent] failed to record lockout: #{e.class}: #{e.message}")
    nil
  end

  private

  def notify
    LoginEventNotifier.call(self)
  end
end
