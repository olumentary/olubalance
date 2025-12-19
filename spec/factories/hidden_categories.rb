# frozen_string_literal: true

FactoryBot.define do
  factory :hidden_category do
    association :user
    association :category
  end
end

