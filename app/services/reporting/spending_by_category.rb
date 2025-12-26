# frozen_string_literal: true

module Reporting
  class SpendingByCategory
    attr_reader :user, :start_date, :end_date, :category_ids, :account_ids

    def initialize(user:, start_date: nil, end_date: nil, category_ids: [], account_ids: [])
      @user = user
      @start_date = start_date || Date.current.beginning_of_month
      @end_date = end_date || Date.current
      @category_ids = Array(category_ids).reject(&:blank?)
      @account_ids = Array(account_ids).reject(&:blank?)
    end

    def call
      {
        categories: category_names,
        current_period: current_period_data,
        previous_period: previous_period_data,
        totals: totals_data
      }
    end

    private

    def base_transactions
      transactions = Transaction.joins(:account)
                                .where(accounts: { user_id: user.id, active: true })
                                .where(pending: false)
                                .where('amount < 0') # Only spending (debits)

      transactions = transactions.where(account_id: account_ids) if account_ids.any?
      transactions = transactions.where(category_id: category_ids) if category_ids.any?

      transactions
    end

    def current_period_transactions
      base_transactions.where(trx_date: start_date..end_date)
    end

    def previous_period_transactions
      # Calculate equivalent previous period
      period_length = (end_date - start_date).to_i
      prev_end = start_date - 1.day
      prev_start = prev_end - period_length.days

      base_transactions.where(trx_date: prev_start..prev_end)
    end

    def spending_by_category(transactions)
      # Group by category and sum absolute amounts
      result = transactions
        .left_joins(:category)
        .group('COALESCE(categories.name, \'Uncategorized\')')
        .sum('ABS(transactions.amount)')

      result.transform_values { |v| v.round(2) }
    end

    def current_spending
      @current_spending ||= spending_by_category(current_period_transactions)
    end

    def previous_spending
      @previous_spending ||= spending_by_category(previous_period_transactions)
    end

    def category_names
      # Union of all categories from both periods, sorted alphabetically
      (current_spending.keys | previous_spending.keys).sort
    end

    def current_period_data
      {
        label: format_period_label(start_date, end_date),
        data: category_names.map { |cat| current_spending[cat] || 0 }
      }
    end

    def previous_period_data
      period_length = (end_date - start_date).to_i
      prev_end = start_date - 1.day
      prev_start = prev_end - period_length.days

      {
        label: format_period_label(prev_start, prev_end),
        data: category_names.map { |cat| previous_spending[cat] || 0 }
      }
    end

    def totals_data
      current_total = current_spending.values.sum
      previous_total = previous_spending.values.sum
      difference = current_total - previous_total
      percentage_change = previous_total.positive? ? ((difference / previous_total) * 100).round(1) : 0

      {
        current: current_total.round(2),
        previous: previous_total.round(2),
        difference: difference.round(2),
        percentage_change: percentage_change
      }
    end

    def format_period_label(period_start, period_end)
      if period_start.month == period_end.month && period_start.year == period_end.year
        period_start.strftime('%b %Y')
      else
        "#{period_start.strftime('%b %d')} - #{period_end.strftime('%b %d, %Y')}"
      end
    end
  end
end

