# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "categories rake tasks" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  let(:backfill_task) { Rake::Task["categories:backfill"] }
  let(:lookup_task) { Rake::Task["categories:backfill_lookups"] }

  after do
    backfill_task.reenable
    lookup_task.reenable
  end

  it "updates uncategorized transactions when a suggestion exists" do
    transaction = create(:transaction, :non_pending, category: nil)
    suggested_category = create(:category, user: transaction.account.user)
    suggestion = CategorySuggester::Suggestion.new(category: suggested_category, confidence: 0.8, source: :lookup)
    allow(CategorySuggester).to receive(:new).and_return(instance_double(CategorySuggester, suggest: suggestion))

    expect {
      backfill_task.invoke
    }.to change { transaction.reload.category }.from(nil).to(suggested_category)
  end

  it "builds category lookups from existing categorized transactions" do
    category = create(:category)
    account = create(:account, user: category.user)
    # Create transaction without category first, then set category via update_columns
    # to bypass the after_commit callback (simulating pre-existing categorized transactions)
    transaction = create(:transaction, :non_pending, description: "Whole Foods", category: nil, account: account)
    transaction.update_columns(category_id: category.id)

    expect {
      lookup_task.invoke
    }.to change { CategoryLookup.count }.by(1)

    lookup = CategoryLookup.last
    expect(lookup.user).to eq(transaction.account.user)
    expect(lookup.category).to eq(category)
    expect(lookup.description_norm).to eq("whole foods")
  end
end

