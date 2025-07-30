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

  has_many :accounts, dependent: :destroy
  has_many :documents, as: :attachable, dependent: :destroy
end
