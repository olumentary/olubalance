# frozen_string_literal: true

# Represents a browser that has successfully cleared the 2FA challenge and
# elected to be remembered. The plaintext token lives only in the user's
# signed cookie; the database stores its SHA256 digest.
class TrustedDevice < ApplicationRecord
  belongs_to :user

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  COOKIE_NAME = :_olubalance_td

  def self.remember_days
    ENV.fetch("TWO_FACTOR_REMEMBER_DAYS", "14").to_i.clamp(1, 90)
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  # Creates a new trusted-device row for `user` and returns the plaintext token
  # to set in the cookie (the digest is what is persisted).
  def self.issue!(user:, user_agent:, ip:)
    token = SecureRandom.hex(32)
    create!(
      user:         user,
      token_digest: digest(token),
      user_agent:   user_agent.to_s.first(255),
      ip:           ip,
      last_seen_at: Time.current,
      expires_at:   remember_days.days.from_now
    )
    token
  end

  # Returns the TrustedDevice if the token matches an active row, otherwise nil.
  def self.lookup(user:, token:)
    return nil if user.blank? || token.blank?

    user.trusted_devices.active.find_by(token_digest: digest(token))
  end

  def touch_last_seen!(ip:)
    update_columns(last_seen_at: Time.current, ip: ip)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def active?
    revoked_at.nil? && expires_at > Time.current
  end
end
