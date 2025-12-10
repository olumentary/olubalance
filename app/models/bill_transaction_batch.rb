# frozen_string_literal: true

require "securerandom"

class BillTransactionBatch < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :nullify

  validates :reference, presence: true, uniqueness: true
  validate :period_or_range_present
  validate :valid_range

  before_validation :assign_reference

  scope :ordered, -> { order(created_at: :desc) }

  def month_label
    return period_month.strftime("%B %Y") if period_month.present?
    return "#{range_start_date.strftime("%b %-d, %Y")} - #{range_end_date.strftime("%b %-d, %Y")}" if range_start_date.present? && range_end_date.present?

    "Custom range"
  end

  private

  def assign_reference
    self.reference ||= SecureRandom.uuid
  end

  def period_or_range_present
    return if period_month.present?
    return if range_start_date.present? && range_end_date.present?

    errors.add(:base, "Specify either period_month or a date range")
  end

  def valid_range
    return unless range_start_date.present? && range_end_date.present?
    return if range_start_date <= range_end_date

    errors.add(:range_end_date, "must be on or after the start date")
  end
end


