# frozen_string_literal: true

class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    # Redirect desktop users to accounts page
    unless mobile_device?
      redirect_to accounts_path
      return
    end
    
    # Mobile users see the simple home page
  end
end