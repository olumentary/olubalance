# frozen_string_literal: true

# Devise user class
class User < ApplicationRecord
  devise :database_authenticatable, :two_factor_backupable,
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
  has_many :authenticators, dependent: :destroy
  belongs_to :default_account, class_name: "Account", optional: true

  # 2FA is "active" iff at least one confirmed authenticator exists.
  def two_factor_enabled?
    authenticators.confirmed.exists?
  end

  # Removes every enrolled authenticator + clears backup codes + revokes
  # trusted devices. After this returns, the user signs in with password only.
  def disable_two_factor!
    transaction do
      authenticators.destroy_all
      update!(otp_backup_codes: [])
      trusted_devices.update_all(revoked_at: Time.current)
    end
  end

  private

  def default_account_belongs_to_user
    return unless default_account_id.present?

    unless accounts.exists?(id: default_account_id)
      errors.add(:default_account_id, "must be one of your accounts")
    end
  end
end
