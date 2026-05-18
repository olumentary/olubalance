# frozen_string_literal: true

# Rack::Attack — throttling + blocklist for auth endpoints.
#
# Counters are stored in Rails.cache (Redis in prod/staging). Tests bypass
# the middleware entirely via `Rack::Attack.enabled = false`.
class Rack::Attack
  Rack::Attack.enabled = !Rails.env.test?
  Rack::Attack.cache.store = Rails.cache

  ### Helpers

  LOGIN_PATH        = "/users/sign_in"
  PASSWORD_PATH     = "/users/password"
  CONFIRMATION_PATH = "/users/confirmation"

  def self.normalized_email(req)
    return nil unless req.params["user"].is_a?(Hash)

    email = req.params["user"]["email"].to_s
    return nil if email.blank?

    email.downcase.strip
  end

  def self.auth_post?(req, path)
    req.post? && req.path == path
  end

  ### Throttles

  throttle("logins/ip", limit: 5, period: 15.minutes) do |req|
    req.ip if auth_post?(req, LOGIN_PATH)
  end

  throttle("logins/email", limit: 5, period: 15.minutes) do |req|
    normalized_email(req) if auth_post?(req, LOGIN_PATH)
  end

  throttle("password_resets/ip", limit: 3, period: 1.hour) do |req|
    req.ip if auth_post?(req, PASSWORD_PATH)
  end

  throttle("password_resets/email", limit: 3, period: 1.hour) do |req|
    normalized_email(req) if auth_post?(req, PASSWORD_PATH)
  end

  throttle("confirmations/ip", limit: 3, period: 1.hour) do |req|
    req.ip if auth_post?(req, CONFIRMATION_PATH)
  end

  ### Fail2ban-style blocklist
  # Any IP that trips a throttle 10+ times in 24h gets a 24h block.
  blocklist("fail2ban/auth") do |req|
    Rack::Attack::Allow2Ban.filter(
      "auth-abuse:#{req.ip}",
      maxretry: 10,
      findtime: 24.hours,
      bantime:  24.hours
    ) do
      # tripping condition: any throttled request on auth paths
      false
    end
  end

  ### Response

  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period] || 60
    [
      429,
      { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
      [ { error: "Too many requests. Try again later." }.to_json ]
    ]
  end

  self.blocklisted_responder = lambda do |_request|
    [
      403,
      { "Content-Type" => "application/json" },
      [ { error: "Forbidden." }.to_json ]
    ]
  end
end

### Notifications — feeds Phase 5's login_events table when LoginEvent is loaded.
ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _request_id, payload|
  request = payload[:request]
  next unless request

  Rails.logger.warn(
    "[rack-attack] throttle matched=#{request.env['rack.attack.matched']} ip=#{request.ip} path=#{request.path}"
  )

  if defined?(LoginEvent)
    LoginEvent.record_rack_attack(request: request, event_type: :throttle)
  end
end

ActiveSupport::Notifications.subscribe("blocklist.rack_attack") do |_name, _start, _finish, _request_id, payload|
  request = payload[:request]
  next unless request

  Rails.logger.warn(
    "[rack-attack] block matched=#{request.env['rack.attack.matched']} ip=#{request.ip} path=#{request.path}"
  )

  if defined?(LoginEvent)
    LoginEvent.record_rack_attack(request: request, event_type: :block)
  end
end
