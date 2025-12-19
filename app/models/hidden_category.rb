# frozen_string_literal: true

class HiddenCategory < ApplicationRecord
  belongs_to :user
  belongs_to :category

  validates :category_id, uniqueness: { scope: :user_id }
end

