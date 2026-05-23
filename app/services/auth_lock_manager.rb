# frozen_string_literal: true

# Resets auth-related lock state from an authenticated admin session:
#   * Devise `:lockable` account locks (clears failed_attempts + locked_at).
#   * Rack::Attack per-IP throttle counters for the auth endpoints.
#   * Rack::Attack fail2ban blocklist entries.
#
# Only clears state for the IP / user explicitly passed in — never globally.
class AuthLockManager
  # IP-keyed throttles defined in config/initializers/rack_attack.rb. Map of
  # throttle name → period; used to compute Rack::Attack cache-bucket keys.
  IP_THROTTLES = {
    "logins/ip"          => 15.minutes,
    "password_resets/ip" => 1.hour,
    "confirmations/ip"   => 1.hour
  }.freeze

  FAIL2BAN_KEY_PREFIX = "auth-abuse"
  FAIL2BAN_BANTIME    = 24.hours
  FAIL2BAN_FINDTIME   = 24.hours
  RACK_ATTACK_PREFIX  = "rack::attack"

  def self.unlock_user!(user)
    user.unlock_access!
  end

  # Clears every counter and ban entry for the given IP. Safe to call when no
  # state exists — delete-on-missing is a no-op in every cache store we use.
  def self.clear_ip!(ip)
    ip = ip.to_s.strip
    return false if ip.blank?

    clear_throttle_counters_for(ip)
    clear_fail2ban_for(ip)
    true
  end

  # Rack::Attack stores per-period buckets at
  #   "rack::attack:#{epoch / period}:#{name}:#{discriminator}"
  # so we delete both the current and previous bucket — a request that just
  # rolled over its window otherwise stays counted against the user.
  def self.clear_throttle_counters_for(ip)
    now = Time.now.to_i
    IP_THROTTLES.each do |name, period|
      period_s = period.to_i
      current_bucket = now / period_s
      [ current_bucket, current_bucket - 1 ].each do |bucket|
        Rack::Attack.cache.store.delete("#{RACK_ATTACK_PREFIX}:#{bucket}:#{name}:#{ip}")
      end
    end
  end

  def self.clear_fail2ban_for(ip)
    Rack::Attack::Allow2Ban.reset(
      "#{FAIL2BAN_KEY_PREFIX}:#{ip}",
      bantime:  FAIL2BAN_BANTIME,
      findtime: FAIL2BAN_FINDTIME
    )
  end
end
