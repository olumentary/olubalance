# frozen_string_literal: true

class Category < ApplicationRecord
  enum :kind, { global: 0, custom: 1 }

  belongs_to :user, optional: true
  has_many :transactions, dependent: :nullify

  before_validation :normalize_name

  validates :name, presence: true, length: { maximum: 80 }
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }

  scope :for_user, ->(user) { where(user_id: [ nil, user.id ]) }
  scope :ordered, -> { order(:name) }

  private

  def normalize_name
    self.name = name.to_s.squish
  end
end

