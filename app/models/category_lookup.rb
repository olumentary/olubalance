# frozen_string_literal: true

class CategoryLookup < ApplicationRecord
  belongs_to :user
  belongs_to :category

  validates :description_norm, presence: true
  validates :usage_count, numericality: { greater_than_or_equal_to: 0 }

  before_validation :normalize_description

  scope :for_user, ->(user) { where(user_id: user.id) }

  def self.normalize(text)
    text.to_s.downcase.squish
  end

  def self.upsert_for(user:, category:, description:)
    norm = normalize(description)
    return if norm.blank? || user.blank? || category.blank?

    lookup = find_or_initialize_by(user_id: user.id, description_norm: norm)
    lookup.category = category
    lookup.usage_count = lookup.usage_count.to_i + 1
    lookup.last_used_at = Time.current
    lookup.save!
    lookup
  end

  def self.suggest_for(user:, description:)
    norm = normalize(description)
    return if norm.blank?

    exact = find_by(user_id: user.id, description_norm: norm)
    return exact if exact

    similarity_order = Arel.sql("similarity(description_norm, #{connection.quote(norm)}) DESC")

    where(user_id: user.id)
      .where("similarity(description_norm, ?) >= 0.3", norm)
      .order(similarity_order, usage_count: :desc, last_used_at: :desc)
      .first
  end

  private

  def normalize_description
    self.description_norm = self.class.normalize(description_norm.presence || description_norm_was || "")
  end
end

