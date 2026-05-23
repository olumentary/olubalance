# frozen_string_literal: true

class UserDecorator < Draper::Decorator
  decorates_finders
  decorates_association :account
  delegate_all
  include Draper::LazyHelpers

  def full_name
    first_name + " " + last_name
  end

  def member_since
    created_at.in_time_zone(timezone).strftime("%b %d, %Y")
  end

  def streak_display
    pluralize(current_streak_weeks, "week")
  end

  # Renders the encouragement / accountability microcopy beneath the streak.
  # Three states:
  #   - never built a streak  -> nudge to start
  #   - active streak         -> celebrate, show personal best
  #   - lapsed streak         -> recovery prompt referencing the best to date
  def streak_subtitle
    if current_streak_weeks.zero? && longest_streak_weeks.zero?
      "Start a streak by reviewing every account this week"
    elsif current_streak_weeks.zero?
      "Restart this week — your best was #{pluralize(longest_streak_weeks, "week")}"
    else
      "Best: #{pluralize(longest_streak_weeks, "week")}"
    end
  end

  def streak_color_class
    case current_streak_weeks
    when 0 then "has-text-black"
    when 1..3 then "has-text-warning-dark"
    else "has-text-success"
    end
  end

  def week_range_display(today: Date.current)
    start_date = today.beginning_of_week(:sunday)
    end_date = today.end_of_week(:sunday)
    "#{start_date.strftime('%b %-d')} – #{end_date.strftime('%b %-d')}"
  end

  def active_accounts_count
    accounts.where(active: true).count
  end

  def accounts_reviewed_this_week_count(today: Date.current)
    accounts.where(active: true).select { |a| a.reviewed_this_week?(today) }.size
  end

  def accounts_needing_review_count(today: Date.current)
    active_accounts_count - accounts_reviewed_this_week_count(today: today)
  end

  def week_complete?(today: Date.current)
    active_accounts_count.positive? && accounts_needing_review_count(today: today).zero?
  end

  # Banner color escalates with day-of-week when the week is incomplete.
  # Sun–Thu = info (informational), Fri = warning, Sat = danger.
  # All-clear states paint success regardless of day.
  def weekly_banner_color_class(today: Date.current)
    return "is-success" if week_complete?(today: today)
    return "is-danger" if today.saturday?
    return "is-warning" if today.friday?

    "is-info"
  end

  def weekly_progress_message(today: Date.current)
    return "All accounts reviewed for the week — nice." if week_complete?(today: today)

    remaining = accounts_needing_review_count(today: today)
    if today.saturday?
      "Saturday — #{pluralize(remaining, "account")} still pending. Finish before midnight."
    elsif today.friday?
      "Friday — #{pluralize(remaining, "account")} still pending."
    else
      "#{pluralize(remaining, "account")} left for the week."
    end
  end
end
