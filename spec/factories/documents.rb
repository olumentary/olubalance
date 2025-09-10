# frozen_string_literal: true

FactoryBot.define do
  factory :document do
    association :attachable, factory: :user
    category { 'Statements' }
    document_date { Date.current }
    description { Faker::Lorem.sentence(word_count: rand(5..15)) }
    tax_year { nil }

    # Always include attachment since it's required
    after(:build) do |document|
      document.attachment.attach(
        io: File.open(Rails.root.join('app', 'assets', 'images', 'logo.png')),
        filename: "test-document-#{SecureRandom.hex(8)}.png",
        content_type: 'image/png'
      )
    end

    trait :tax_document do
      category { 'Taxes' }
      tax_year { 2023 }
    end

    trait :user_level do
      association :attachable, factory: :user
    end

    trait :account_level do
      association :attachable, factory: :account
    end

    factory :user_document, traits: [:user_level]
    factory :account_document, traits: [:account_level]
    factory :tax_document, traits: [:tax_document]
  end
end 