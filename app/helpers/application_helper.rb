# frozen_string_literal: true

module ApplicationHelper
  # Conditionally joins a set of CSS class names into a single string
  #
  # @param css_map [Hash] a mapping of CSS class names to boolean values
  # @return [String] a combined string of CSS classes where the value was true
  def class_string(css_map)
    classes = []

    css_map.each do |css, bool|
      classes << css if bool
    end

    classes.join(" ")
  end

  # Devise Helpers
  def resource_name
    :user
  end

  def resource
    @resource ||= User.new
  end

  def devise_mapping
    @devise_mapping ||= Devise.mappings[:user]
  end

  def mobile_device?
    request.user_agent =~ /Mobile|Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i
  end
end
