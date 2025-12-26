# frozen_string_literal: true

class Category < ApplicationRecord
  enum :kind, { global: 0, custom: 1 }

  belongs_to :user, optional: true
  has_many :transactions, dependent: :nullify
  has_many :hidden_categories, dependent: :destroy
  has_many :category_lookups, dependent: :destroy

  before_validation :normalize_name

  validates :name, presence: true, length: { maximum: 80 }
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }

  # Returns categories visible to the user: their custom categories + globals not hidden by them
  scope :for_user, ->(user) {
    hidden_ids = HiddenCategory.where(user_id: user.id).select(:category_id)
    where(user_id: [nil, user.id]).where.not(id: hidden_ids)
  }
  scope :ordered, -> { order(:name) }

  def global?
    user_id.nil?
  end

  def self.transfer_category
    find_or_create_by!(name: 'Transfer', kind: :global, user_id: nil)
  end

  private

  def normalize_name
    self.name = name.to_s.squish
  end
end

