# frozen_string_literal: true

# Devise user class
class User < ApplicationRecord
  encrypts :otp_secret

  # NOTE: `:database_authenticatable` is intentionally NOT loaded alongside
  # `:two_factor_authenticatable`. devise-two-factor warns this combination
  # bypasses 2FA via Warden strategy cascading; the latter already provides
  # password auth.
  devise :two_factor_authenticatable, :two_factor_backupable,
         :lockable, :recoverable, :rememberable, :trackable, :validatable, :confirmable,
         otp_number_of_backup_codes: 10

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: Devise.email_regexp
  validates :first_name, presence: { message: "Please enter your First Name" }
  validates :last_name, presence: { message: "Please enter your Last Name" }
  validates :timezone, presence: { message: "Please select a Time Zone" }
  validate :default_account_belongs_to_user, if: :default_account_id?

  has_many :accounts, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :hidden_categories, dependent: :destroy
  has_many :category_lookups, dependent: :destroy
  has_many :documents, as: :attachable, dependent: :destroy
  has_many :bills, dependent: :destroy
  has_many :bill_transaction_batches, dependent: :destroy
  has_many :trusted_devices, dependent: :destroy
  belongs_to :default_account, class_name: "Account", optional: true

  def two_factor_enabled?
    otp_required_for_login?
  end

  def disable_two_factor!
    update!(
      otp_required_for_login: false,
      otp_secret:             nil,
      consumed_timestep:      nil,
      otp_backup_codes:       []
    )
    trusted_devices.update_all(revoked_at: Time.current)
  end

  private

  def default_account_belongs_to_user
    return unless default_account_id.present?

    unless accounts.exists?(id: default_account_id)
      errors.add(:default_account_id, "must be one of your accounts")
    end
  end
end
