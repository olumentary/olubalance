# frozen_string_literal: true

class DataExport < ApplicationRecord
  belongs_to :user
  has_one_attached :archive

  enum :status, { pending: "pending", processing: "processing", complete: "complete", failed: "failed" }

  scope :recent, -> { order(created_at: :desc) }
  scope :expired, -> { where("expires_at < ?", Time.current) }
  scope :in_flight, -> { where(status: %w[pending processing]) }
end
