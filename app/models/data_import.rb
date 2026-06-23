# frozen_string_literal: true

class DataImport < ApplicationRecord
  belongs_to :user
  has_one_attached :archive

  enum :status, { pending: "pending", processing: "processing", complete: "complete", failed: "failed" }

  scope :recent, -> { order(created_at: :desc) }
  scope :in_flight, -> { where(status: %w[pending processing]) }
end
