# frozen_string_literal: true

# An account which will store many transactions and belongs to one user
class Account < ApplicationRecord
  # Define Constants
  NO_ACCOUNT_DESC = "It looks like you don't have any accounts added. To add an account, \
                     click the <span class='has-text-weight-bold'>New</span> button at the top of the page :)"

  NO_INACTIVE_DESC = "You have no inactive accounts :)"

  DISPLAY_NAME_LIMIT = 18

  belongs_to :user
  has_many :transactions, dependent: :delete_all
  has_many :stashes, dependent: :delete_all
  has_many :documents, as: :attachable, dependent: :destroy
  has_many :bills, dependent: :destroy

  validates :name, presence: true,
                   length: { maximum: 50, minimum: 2 },
                   uniqueness: { scope: :user_id }

  validates :starting_balance, presence: true
  validates :last_four, length: { minimum: 4, maximum: 4 },
                        format: { with: /\A\d+\z/, message: "Numbers only." },
                        allow_blank: true
  validates :interest_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }, unless: proc { |u|
                                                                                                     !u.credit?
                                                                                                   }
  validates :interest_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }, unless: proc { |u|
                                                                                                     !u.savings?
                                                                                                   }
  validates :credit_limit, presence: true, numericality: { greater_than_or_equal_to: 0 }, unless: proc { |u|
                                                                                                    !u.credit?
                                                                                                  }
  validates :statement_day,
            numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 31 },
            allow_nil: true

  before_create :set_current_balance
  after_create :create_initial_transaction

  enum :account_type, {
    checking: "checking",
    savings: "savings",
    credit: "credit",
    cash: "cash"
  }

  validates :account_type, inclusion: {
    in: account_types.keys
  }

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # Sum of Pending Transactions
  def pending_balance
    transactions.where(pending: true).sum(:amount)
  end

  def non_pending_balance
    transactions.where(pending: false).sum(:amount)
  end

  def available_credit
    if current_balance.abs <= credit_limit
      credit_limit - current_balance.abs
    else
      0
    end
  end

  def credit_utilization
    ((current_balance.abs / credit_limit) * 100).round(2)
  end

  # True if the account has been "touched" (transaction or manual review)
  # at any point during the current Sunday→Saturday week. The clock advances
  # via Account.last_transaction_on, which is stamped both by real
  # transactions and by the explicit "mark reviewed for the week" action.
  def reviewed_this_week?(today = Date.current)
    return false if last_transaction_on.blank?

    last_transaction_on >= today.beginning_of_week(:sunday)
  end

  # True if this account existed on or before the given date. Used by the
  # streak evaluator to skip brand-new accounts when judging a week that
  # predates their creation.
  def existed_at?(date)
    created_at.to_date <= date
  end

  # Accounts missing any required config are silently skipped by the interest job.
  def interest_eligible?
    credit? &&
      interest_rate.present? && interest_rate.positive? &&
      statement_day.present? &&
      current_balance.present? && current_balance.negative?
  end

  def clamped_statement_day(date)
    [ statement_day, date.end_of_month.day ].min
  end

  def interest_due_on?(date)
    return false if statement_day.blank?
    return false unless date.day == clamped_statement_day(date)

    last_interest_charged_on.blank? || last_interest_charged_on < date.beginning_of_month
  end

  # Simple monthly periodic rate: balance × (APR ÷ 12).
  # APR is stored as a percentage (e.g. 24.99), so the divisor is 1200 in one step.
  def monthly_interest_amount
    return BigDecimal("0") unless interest_rate.present? && current_balance.present?

    rate = interest_rate.is_a?(BigDecimal) ? interest_rate : interest_rate.to_d
    balance = current_balance.is_a?(BigDecimal) ? current_balance.abs : current_balance.to_d.abs
    (balance * rate / BigDecimal("1200")).round(2)
  end

  private

  def set_current_balance
    self.current_balance = starting_balance
  end

  def create_initial_transaction
    Transaction.skip_callback(:create, :after, :update_account_balance_create)
    init_trx = Transaction.new
    init_trx.trx_type = "credit"
    init_trx.trx_date = Time.current
    init_trx.account_id = id
    init_trx.description = "Starting Balance"
    init_trx.amount = starting_balance
    init_trx.memo = "This is the beginning transaction of the account."
    init_trx.skip_pending_default = true
    init_trx.locked = true
    init_trx.save
    Transaction.set_callback(:create, :after, :update_account_balance_create)
  end
end
