# frozen_string_literal: true

require "rails_helper"

RSpec.describe StashDecorator do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:stash) {
    Stash.create!(account: account, name: "Vacation", description: "trip",
                  goal: BigDecimal("1000"), balance: BigDecimal("250"))
  }
  let(:decorated) { stash.decorate }

  it "formats balance as currency" do
    expect(decorated.balance_display).to eq(ActionController::Base.helpers.number_to_currency(250))
  end

  it "formats goal as currency" do
    expect(decorated.goal_display).to eq(ActionController::Base.helpers.number_to_currency(1000))
  end

  it "reports balance with 2-decimal precision" do
    expect(decorated.balance).to eq("250.00")
  end

  describe "#progress" do
    it "is the balance/goal percentage (rounded)" do
      expect(decorated.progress).to eq(25)
    end

    it "is 0 when the goal is zero (avoid divide by zero)" do
      stash.update_columns(goal: 0)
      expect(stash.reload.decorate.progress).to eq(0)
    end
  end

  describe "#progress_class" do
    it "uses light text when progress is >= 50" do
      stash.update_columns(balance: BigDecimal("750"))
      expect(stash.reload.decorate.progress_class).to eq("has-text-white")
    end

    it "uses grey text when progress is < 50" do
      expect(decorated.progress_class).to eq("has-text-grey")
    end
  end
end
