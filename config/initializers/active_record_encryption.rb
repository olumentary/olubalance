# frozen_string_literal: true

# ActiveRecord encryption is used to encrypt sensitive columns (e.g. `users.otp_secret`).
# Production keys come from environment variables (set via Figaro / Dokku config).
# Dev/test fall back to deterministic local keys so the app boots without setup.
#
# To generate production keys: `bin/rails db:encryption:init` then copy the
# `primary_key`, `deterministic_key`, and `key_derivation_salt` values into the env.

primary_key            = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
deterministic_key      = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
key_derivation_salt    = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]

if Rails.env.production? || Rails.env.staging?
  unless primary_key.present? && deterministic_key.present? && key_derivation_salt.present?
    raise "ActiveRecord encryption keys are required in #{Rails.env}. " \
          "Set ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY, ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY, " \
          "and ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT in the environment."
  end
else
  primary_key         ||= "dev_primary_key_change_me_in_production_____________"
  deterministic_key   ||= "dev_deterministic_key_change_me_in_production_______"
  key_derivation_salt ||= "dev_key_derivation_salt_change_me_in_production"
end

Rails.application.config.active_record.encryption.primary_key         = primary_key
Rails.application.config.active_record.encryption.deterministic_key   = deterministic_key
Rails.application.config.active_record.encryption.key_derivation_salt = key_derivation_salt
