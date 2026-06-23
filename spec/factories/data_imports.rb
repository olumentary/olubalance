# frozen_string_literal: true

FactoryBot.define do
  factory :data_import do
    association :user
    status { :pending }
    progress { 0 }

    trait :processing do
      status { :processing }
      progress { 50 }
      step { "Importing transactions" }
    end

    trait :complete do
      status { :complete }
      progress { 100 }
      step { "Done" }
    end

    trait :failed do
      status { :failed }
      error_message { "Something went wrong" }
    end
  end
end
