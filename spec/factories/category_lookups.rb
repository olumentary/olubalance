# frozen_string_literal: true

FactoryBot.define do
  factory :category_lookup do
    association :user
    association :category
    description_norm { "grocery" }
    usage_count { 1 }
    last_used_at { Time.current }
  end
end

