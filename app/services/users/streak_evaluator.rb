# frozen_string_literal: true

module Users
  # Updates a user's weekly review streak. Run by StreakEvaluationJob each
  # Sunday at 00:05 in server time; safe to invoke directly from console.
  #
  # A week "counts" iff EVERY active account that existed by the week's end
  # has `last_transaction_on >= week_start` — meaning the user either added a
  # transaction or hit "mark reviewed for the week" sometime within (or
  # after) that week. Brand-new accounts created after the week ended are
  # skipped so they don't retroactively fail the streak.
  #
  # `on:` defaults to today in the user's timezone. The evaluator judges the
  # week that ended on the prior Saturday. If the evaluator skipped one or
  # more weeks (Sidekiq downtime), the streak resets — we can't honestly
  # claim a week was clean if we never checked.
  class StreakEvaluator
    def self.call(user, on: nil)
      new(user, on: on).call
    end

    def initialize(user, on: nil)
      @user = user
      @today = on || Time.use_zone(user.timezone) { Date.current }
    end

    def call
      return if user.accounts.active.none?

      previous = user.streak_last_evaluated_on
      return if previous.present? && previous >= @today.beginning_of_week(:sunday)

      if previous.present? && (@today - previous).to_i > 7
        user.update_columns(current_streak_weeks: 0)
      end

      new_current =
        if clean_week?
          user.current_streak_weeks + 1
        else
          0
        end

      new_longest = [ user.longest_streak_weeks, new_current ].max

      user.update_columns(
        current_streak_weeks: new_current,
        longest_streak_weeks: new_longest,
        streak_last_evaluated_on: @today
      )
    end

    private

    attr_reader :user

    def clean_week?
      user.accounts.active.all? do |account|
        next true unless account.existed_at?(last_week_end)

        account.last_transaction_on.present? && account.last_transaction_on >= last_week_start
      end
    end

    def last_week_start
      @last_week_start ||= @today.beginning_of_week(:sunday) - 7.days
    end

    def last_week_end
      @last_week_end ||= last_week_start + 6.days
    end
  end
end
