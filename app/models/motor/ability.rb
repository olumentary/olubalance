# frozen_string_literal: true

module Motor
  class Ability
    include CanCan::Ability

    def initialize(user)
      return unless user&.admin?

      can :manage, :all
    end
  end
end
