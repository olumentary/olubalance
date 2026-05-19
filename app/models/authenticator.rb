# frozen_string_literal: true

# Represents a single enrolled TOTP authenticator (e.g. one phone's
# authenticator app). A user may have many — each row holds its own secret
# so two people sharing the same account can each enroll their own device.
#
# `consumed_timestep` is per-authenticator replay protection: once a code is
# consumed it cannot be replayed against the same secret.
class Authenticator < ApplicationRecord
  OTP_SECRET_LENGTH = 32
  TOTP_INTERVAL     = 30
  DRIFT             = 30 # seconds tolerated either side of the server clock

  belongs_to :user

  encrypts :otp_secret

  validates :nickname, presence: true, length: { maximum: 50 },
                       uniqueness: { scope: :user_id, case_sensitive: false }
  validates :otp_secret,   presence: true
  validates :confirmed_at, presence: true

  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :recent_first, -> { order(created_at: :desc) }

  # Generates a fresh base32-encoded TOTP secret.
  def self.generate_secret
    ROTP::Base32.random_base32(OTP_SECRET_LENGTH)
  end

  # Returns the otpauth:// URI for QR-encoding.
  def self.provisioning_uri(secret:, account:, issuer: "olubalance")
    ROTP::TOTP.new(secret, issuer: issuer).provisioning_uri(account)
  end

  # Verifies the given 6-digit code against this authenticator's secret with
  # ±30s drift. Returns true on success and updates `consumed_timestep` +
  # `last_used_at` atomically; returns false otherwise. Refuses to accept the
  # same code twice (replay protection).
  def validate_and_consume!(code)
    return false if code.blank?

    totp        = ROTP::TOTP.new(otp_secret)
    matched_at  = totp.verify(code.to_s, drift_behind: DRIFT, drift_ahead: DRIFT, after: previous_otp_at)
    return false unless matched_at

    update!(consumed_timestep: matched_at / TOTP_INTERVAL, last_used_at: Time.current)
    true
  end

  def current_code
    ROTP::TOTP.new(otp_secret).now
  end

  private

  # ROTP's `after:` argument refuses any OTP at or before that Unix timestamp,
  # which gives us replay protection.
  def previous_otp_at
    return nil if consumed_timestep.blank?

    consumed_timestep * TOTP_INTERVAL
  end
end
