# frozen_string_literal: true

class Bill < ApplicationRecord
  belongs_to :account
  belongs_to :user

  enum :bill_type, {
    income: "income",
    expense: "expense",
    debt_repayment: "debt_repayment",
    payment_plan: "payment_plan"
  }, prefix: true

  enum :category, {
    income: "income",
    utility: "utility",
    family: "family",
    auto: "auto",
    food: "food",
    housing: "housing",
    misc: "misc",
    internet: "internet",
    health: "health",
    insurance: "insurance",
    phone: "phone",
    credit_card: "credit_card",
    taxes: "taxes"
  }, prefix: true

  enum :frequency, {
    monthly: "monthly",
    bi_weekly: "bi_weekly",
    quarterly: "quarterly",
    annual: "annual"
  }, default: :monthly

  validates :bill_type, presence: true, inclusion: { in: bill_types.keys }
  validates :category, presence: true, inclusion: { in: categories.keys }
  validates :frequency, inclusion: { in: frequencies.keys }
  validates :description, presence: true, length: { maximum: 150 }
  validates :day_of_month, presence: true,
                           numericality: {
                             only_integer: true,
                             greater_than_or_equal_to: 1,
                             less_than_or_equal_to: 31
                           }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :notes, length: { maximum: 2000 }, allow_blank: true
  validates :account, presence: true
  validates :user, presence: true

  validate :account_belongs_to_user
  validate :anchor_weekday_matches_date

  with_options if: -> { frequency == "bi_weekly" } do
    validates :biweekly_mode, inclusion: { in: %w[two_days every_other_week] }
    validates :second_day_of_month,
              presence: true,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 1,
                less_than_or_equal_to: 31
              },
              if: -> { frequency == "bi_weekly" && biweekly_mode == "two_days" }
    validates :biweekly_anchor_weekday,
              presence: true,
              inclusion: { in: 0..6 },
              if: -> { frequency == "bi_weekly" && biweekly_mode == "every_other_week" }
    validates :biweekly_anchor_date,
              presence: true,
              if: -> { frequency == "bi_weekly" && biweekly_mode == "every_other_week" }
  end

  with_options if: -> { frequency.in?(%w[quarterly annual]) } do
    validates :next_occurrence_month,
              presence: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
  end

  scope :ordered_for_list, -> { order(:day_of_month, :description) }

  delegate :name, to: :account, prefix: true

  before_validation :set_anchor_weekday_from_date

  def calendar_date_for(reference_date = Time.zone.today)
    occurrences_for_month(reference_date).first
  end

  def occurrences_for_month(reference_date = Time.zone.today)
    month_start = reference_date.to_date.beginning_of_month
    month_end = month_start.end_of_month

    case frequency
    when "monthly"
      [clamp_date(day_of_month, month_start)]
    when "bi_weekly"
      biweekly_occurrences(month_start, month_end)
    when "quarterly"
      quarterly_occurrences(month_start, month_end)
    when "annual"
      annual_occurrences(month_start, month_end)
    else
      []
    end
  end

  def monthly_normalized_amount
    amt = amount.to_d

    case frequency
    when "monthly"
      amt
    when "bi_weekly"
      if biweekly_mode == "two_days"
        occurrences_count = [day_of_month, second_day_of_month].compact.size
        amt * occurrences_count
      else
        amt * BigDecimal("26") / BigDecimal("12")
      end
    when "quarterly"
      amt / BigDecimal("3")
    when "annual"
      amt / BigDecimal("12")
    else
      amt
    end
  end

  private

  def biweekly_occurrences(month_start, month_end)
    case biweekly_mode
    when "two_days"
      [day_of_month, second_day_of_month].compact.map { |day| clamp_date(day, month_start) }.sort
    when "every_other_week"
      anchor = biweekly_anchor_date
      return [clamp_date(day_of_month, month_start)] if anchor.blank?

      start_date = anchor
      start_date -= 14 while start_date > month_end
      start_date += 14 while start_date < month_start

      dates = []
      current = start_date
      while current <= month_end
        dates << current
        current += 14
      end
      dates
    else
      [clamp_date(day_of_month, month_start)]
    end
  end

  def quarterly_occurrences(month_start, month_end)
    return [] unless next_occurrence_month

    month_number = month_start.month
    start_month = next_occurrence_month
    month_diff = (month_number - start_month) % 3
    return [] unless month_diff.zero?

    [clamp_date(day_of_month, month_start)]
  end

  def annual_occurrences(month_start, _month_end)
    return [] unless next_occurrence_month
    return [] unless month_start.month == next_occurrence_month

    [clamp_date(day_of_month, month_start)]
  end

  def clamp_date(day, month_start)
    month_start + (clamped_day(day, month_start) - 1).days
  end

  def clamped_day(day, month_start)
    [day, month_start.end_of_month.day].min
  end

  def account_belongs_to_user
    return if account.blank? || user.blank?
    return if account.user_id == user_id

    errors.add(:account_id, "must belong to your profile")
  end

  def set_anchor_weekday_from_date
    return unless biweekly_mode == "every_other_week"
    return unless biweekly_anchor_date.present?

    self.biweekly_anchor_weekday ||= biweekly_anchor_date.wday
  end

  def anchor_weekday_matches_date
    return unless biweekly_anchor_date.present? && biweekly_anchor_weekday.present?
    return if biweekly_anchor_weekday == biweekly_anchor_date.wday

    errors.add(:biweekly_anchor_weekday, "must match the weekday of the anchor date")
  end
end

