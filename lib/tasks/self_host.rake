# frozen_string_literal: true

namespace :self_host do
  desc "Create the initial admin user from ADMIN_* env vars (idempotent; for self-hosted installs)"
  task bootstrap_admin: :environment do
    email = ENV["ADMIN_EMAIL"]
    password = ENV["ADMIN_PASSWORD"]

    if email.blank? || password.blank?
      puts "[self_host:bootstrap_admin] ADMIN_EMAIL / ADMIN_PASSWORD not set; skipping."
      next
    end

    if User.exists?(email: email)
      puts "[self_host:bootstrap_admin] User #{email} already exists; skipping."
      next
    end

    User.create!(
      email: email,
      password: password,
      password_confirmation: password,
      first_name: ENV.fetch("ADMIN_FIRST_NAME", "Admin"),
      last_name:  ENV.fetch("ADMIN_LAST_NAME", "User"),
      timezone:   ENV.fetch("ADMIN_TIMEZONE", "Eastern Time (US & Canada)"),
      admin: true,
      confirmed_at: Time.current
    )

    puts "[self_host:bootstrap_admin] Bootstrapped admin user #{email}."
  end
end
