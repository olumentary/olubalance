# frozen_string_literal: true

require "rails_helper"

RSpec.describe Users::StreakEvaluator do
  let(:user) { create(:user, current_streak_weeks: 0, longest_streak_weeks: 0) }
  # Use a Sunday strictly in the future (relative to "now") so accounts
  # created during the test always satisfy `existed_at?(last_week_end)`.
  # Hardcoded dates rot once the real clock moves past them.
  let(:evaluation_sunday) do
    today = Date.current
    days_ahead = (7 - today.wday) % 7
    days_ahead = 7 if days_ahead.zero?
    today + days_ahead.days
  end
  let(:last_week_start) { evaluation_sunday - 7.days }
  let(:last_week_end) { last_week_start + 6.days }

  describe "no active accounts" do
    it "is a no-op" do
      expect { described_class.call(user, on: evaluation_sunday) }
        .not_to change { user.reload.current_streak_weeks }
    end
  end

  describe "clean week — every account reviewed last week" do
    let!(:account) { create(:account, user: user) }
    let!(:other_account) { create(:account, user: user) }

    before do
      account.update_columns(last_transaction_on: last_week_start + 1.day)
      other_account.update_columns(last_transaction_on: last_week_end)
    end

    it "increments current_streak_weeks by 1" do
      described_class.call(user, on: evaluation_sunday)
      expect(user.reload.current_streak_weeks).to eq(1)
    end

    it "raises longest_streak_weeks when current beats it" do
      user.update_columns(current_streak_weeks: 5, longest_streak_weeks: 5)
      described_class.call(user, on: evaluation_sunday)
      expect(user.reload.longest_streak_weeks).to eq(6)
    end

    it "stamps streak_last_evaluated_on" do
      described_class.call(user, on: evaluation_sunday)
      expect(user.reload.streak_last_evaluated_on).to eq(evaluation_sunday)
    end
  end

  describe "dirty week — at least one account missed" do
    let!(:reviewed) { create(:account, user: user) }
    let!(:missed) { create(:account, user: user) }

    before do
      reviewed.update_columns(last_transaction_on: last_week_start + 2.days)
      missed.update_columns(last_transaction_on: last_week_start - 5.days)
      user.update_columns(current_streak_weeks: 8, longest_streak_weeks: 8)
    end

    it "resets current_streak_weeks to 0" do
      described_class.call(user, on: evaluation_sunday)
      expect(user.reload.current_streak_weeks).to eq(0)
    end

    it "preserves longest_streak_weeks" do
      described_class.call(user, on: evaluation_sunday)
      expect(user.reload.longest_streak_weeks).to eq(8)
    end
  end

  describe "brand-new account (created after the week ended)" do
    let!(:established) { create(:account, user: user) }
    let!(:fresh_account) do
      a = create(:account, user: user)
      # Force created_at past the week boundary
      a.update_columns(created_at: evaluation_sunday.in_time_zone, last_transaction_on: nil)
      a
    end

    before do
      established.update_columns(last_transaction_on: last_week_start + 1.day)
    end

    it "does not punish the streak for accounts that didn't exist yet" do
      described_class.call(user, on: evaluation_sunday)
      expect(user.reload.current_streak_weeks).to eq(1)
    end
  end

  describe "gap longer than 7 days" do
    let!(:account) { create(:account, user: user) }

    it "resets the streak before re-evaluating" do
      account.update_columns(last_transaction_on: last_week_start + 1.day)
      user.update_columns(
        current_streak_weeks: 10,
        longest_streak_weeks: 10,
        streak_last_evaluated_on: evaluation_sunday - 30.days
      )
      described_class.call(user, on: evaluation_sunday)
      # Reset, then a clean week increments back to 1
      expect(user.reload.current_streak_weeks).to eq(1)
    end
  end

  describe "account reviewed on the new week's Sunday counts toward last week" do
    let!(:account) { create(:account, user: user) }

    it "counts the streak when the only review lands on the evaluation Sunday" do
      account.update_columns(last_transaction_on: evaluation_sunday)
      described_class.call(user, on: evaluation_sunday)
      expect(user.reload.current_streak_weeks).to eq(1)
    end
  end
end
