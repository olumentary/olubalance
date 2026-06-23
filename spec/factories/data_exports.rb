# frozen_string_literal: true

FactoryBot.define do
  factory :data_export do
    association :user
    status { :pending }
    progress { 0 }

    trait :processing do
      status { :processing }
      progress { 50 }
      step { "Building manifest" }
    end

    trait :complete do
      status { :complete }
      progress { 100 }
      step { "Done" }
      expires_at { 24.hours.from_now }
    end

    trait :failed do
      status { :failed }
      error_message { "Something went wrong" }
    end
  end
end
