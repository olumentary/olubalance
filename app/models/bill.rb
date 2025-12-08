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

  scope :ordered_for_list, -> { order(:day_of_month, :description) }

  delegate :name, to: :account, prefix: true

  def calendar_date_for(reference_date = Time.zone.today)
    base_date = reference_date.beginning_of_month
    days_in_month = base_date.end_of_month.day
    target_day = [day_of_month, days_in_month].min
    base_date + (target_day - 1).days
  end

  private

  def account_belongs_to_user
    return if account.blank? || user.blank?
    return if account.user_id == user_id

    errors.add(:account_id, "must belong to your profile")
  end
end

