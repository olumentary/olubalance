# frozen_string_literal: true

class SecurityMailer < ApplicationMailer
  # Sent when a single IP racks up suspicious failure counts within a window.
  def suspicious_failed_attempts(user, ip:, count:, window:)
    @user   = user
    @ip     = ip
    @count  = count
    @window = window

    mail(to: user.email, subject: "[olubalance] Suspicious sign-in attempts on your account")
  end

  # Sent when a successful sign-in originates from an IP not seen in the prior
  # FAMILIAR_WINDOW.
  def unfamiliar_successful_login(user, login_event)
    @user        = user
    @login_event = login_event

    mail(to: user.email, subject: "[olubalance] New device or location signed in")
  end
end
