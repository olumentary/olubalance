# frozen_string_literal: true

class StaticPagesController < ApplicationController
  layout "home"
  
  def home
    # Make Devise resources available for the login form
    @resource = User.new
    @resource_name = :user
  end
end
