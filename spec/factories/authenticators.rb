# frozen_string_literal: true

FactoryBot.define do
  factory :authenticator do
    association :user
    sequence(:nickname) { |n| "Device #{n}" }
    otp_secret    { Authenticator.generate_secret }
    confirmed_at  { Time.current }

    trait :unused do
      consumed_timestep { nil }
      last_used_at      { nil }
    end
  end
end
