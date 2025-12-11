# frozen_string_literal: true

FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    kind { :custom }
    association :user

    trait :global do
      kind { :global }
      user { nil }
    end
  end
end

