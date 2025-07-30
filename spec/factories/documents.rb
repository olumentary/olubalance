# frozen_string_literal: true

FactoryBot.define do
  factory :document do
    association :attachable, factory: :user
    category { 'Statements' }
    document_date { Date.current }
    tax_year { nil }

    trait :with_attachments do
      after(:create) do |document|
        document.attachments.attach(
          io: File.open(Rails.root.join('app', 'assets', 'images', 'logo.png')),
          filename: "test-document-#{document.id}.png",
          content_type: 'image/png'
        )
      end
    end

    # Always include attachments since they're required on update
    after(:create) do |document|
      document.attachments.attach(
        io: File.open(Rails.root.join('app', 'assets', 'images', 'logo.png')),
        filename: "test-document-#{document.id}.png",
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

    factory :user_document, traits: [:user_level, :with_attachments]
    factory :account_document, traits: [:account_level, :with_attachments]
    factory :tax_document, traits: [:tax_document, :with_attachments]
  end
end 