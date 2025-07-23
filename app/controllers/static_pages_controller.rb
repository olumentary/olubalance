# frozen_string_literal: true

class StaticPagesController < ApplicationController
  before_action :authenticate_user!, only: [:mobile_home]
  layout "home", only: [:home]
  
  def home
    if mobile_device?
      redirect_to mobile_home_path
    else
      redirect_to accounts_path
    end
  end

  def mobile_home
    # This action will serve the mobile-specific home page
  end
end
