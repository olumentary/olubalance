# frozen_string_literal: true

class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    # Simple mobile home page - no account data needed
  end
end