# frozen_string_literal: true

class StashDecorator < ApplicationDecorator
  decorates_finders
  decorates_association :stash_entry
  delegate_all
  include Draper::LazyHelpers

  def balance_display
    number_to_currency(balance)
  end

  def balance
    number_with_precision(object.balance, precision: 2)
  end

  def goal_display
    number_to_currency(goal)
  end

  def goal
    number_with_precision(object.goal, precision: 2)
  end

  def progress
    return 0 if object.goal.zero?

    (object.balance / object.goal * 100.00).round
  end

  def progress_class
    progress >= 50 ? "has-text-white" : "has-text-grey"
  end
end
