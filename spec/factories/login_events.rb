# frozen_string_literal: true

FactoryBot.define do
  factory :login_event do
    user             { nil }
    email_attempted  { "attacker@example.com" }
    ip               { "203.0.113.10" }
    user_agent       { "curl/8.0" }
    event_type       { "failure" }
    reason           { "invalid_password" }
    metadata         { {} }

    trait :success do
      event_type { "success" }
      reason     { nil }
      association :user
      email_attempted { user&.email }
    end

    trait :otp_success do
      event_type { "otp_success" }
      reason     { nil }
      association :user
    end

    trait :otp_failure do
      event_type { "otp_failure" }
      reason     { "invalid_code" }
      association :user
    end

    trait :lockout do
      event_type { "lockout" }
      reason     { "max_failed_attempts" }
      association :user
    end

    trait :throttle do
      event_type { "throttle" }
      reason     { "logins/ip" }
    end

    trait :block do
      event_type { "block" }
      reason     { "fail2ban/auth" }
    end
  end
end
