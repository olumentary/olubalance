# frozen_string_literal: true

FactoryBot.define do
  factory :trusted_device do
    association :user
    token_digest { TrustedDevice.digest(SecureRandom.hex(32)) }
    user_agent   { "Mozilla/5.0 (Macintosh)" }
    ip           { "192.0.2.1" }
    last_seen_at { Time.current }
    expires_at   { 14.days.from_now }
    revoked_at   { nil }

    trait :revoked do
      revoked_at { Time.current }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
