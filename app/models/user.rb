# frozen_string_literal: true

# Devise user class
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :trackable, :validatable, :confirmable

  # validates :password_confirmation, presence: true

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: Devise.email_regexp
  validates :first_name, presence: { message: "Please enter your First Name" }
  validates :last_name, presence: { message: "Please enter your Last Name" }
  validates :timezone, presence: { message: "Please select a Time Zone" }
  validate :default_account_belongs_to_user, if: :default_account_id?

  has_many :accounts, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :documents, as: :attachable, dependent: :destroy
  has_many :bills, dependent: :destroy
  has_many :bill_transaction_batches, dependent: :destroy
  belongs_to :default_account, class_name: 'Account', optional: true

  private

  def default_account_belongs_to_user
    return unless default_account_id.present?
    
    unless accounts.exists?(id: default_account_id)
      errors.add(:default_account_id, "must be one of your accounts")
    end
  end
end
