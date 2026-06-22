# frozen_string_literal: true

class UserDecorator < Draper::Decorator
  decorates_finders
  decorates_association :account
  delegate_all
  include Draper::LazyHelpers

  def full_name
    first_name + " " + last_name
  end

  def member_since
    created_at.in_time_zone(timezone).strftime("%b %d, %Y")
  end

  def active_accounts_count
    accounts.where(active: true).count
  end
end
