# frozen_string_literal: true

class StreakEvaluationJob < ApplicationJob
  queue_as :default

  def perform
    User.find_each do |user|
      Users::StreakEvaluator.call(user)
    end
  end
end
