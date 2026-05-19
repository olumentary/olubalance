# frozen_string_literal: true

module TwoFactorSettingsHelper
  # Confirmation copy varies depending on whether this is the *last*
  # authenticator — removing the last one disables 2FA entirely.
  def removal_confirmation(authenticator)
    if current_user.authenticators.confirmed.count <= 1
      "This is your only authenticator. Removing it will disable 2FA and revoke all trusted devices. Continue?"
    else
      "Remove #{authenticator.nickname}?"
    end
  end
end
