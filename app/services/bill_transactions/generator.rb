# frozen_string_literal: true

require "set"
require "ostruct"

module BillTransactions
  class Generator
    PreviewItem = Struct.new(:bill, :account, :trx_date, :amount, :description, keyword_init: true) do
      def trx_type
        amount.negative? ? "debit" : "credit"
      end
    end

    def initialize(user:)
      @user = user
    end

    def preview(period_month: nil, start_date: nil, end_date: nil, bill: nil)
      range = normalize_range(period_month: period_month, start_date: start_date, end_date: end_date)
      bills = bill.present? ? Array(bill) : @user.bills.includes(:account)

      bills.flat_map do |b|
        occurrences_for_bill(b, range)
      end.compact.sort_by { |item| [item.trx_date, item.description, item.account.name] }
    end

    def generate!(period_month: nil, start_date: nil, end_date: nil, bill: nil)
      range = normalize_range(period_month: period_month, start_date: start_date, end_date: end_date)
      items = preview(period_month: period_month, start_date: start_date, end_date: end_date, bill: bill)
      return OpenStruct.new(batch: nil, created_transactions: []) if items.empty?

      existing = existing_keys(range)
      items_to_create = []

      items.each do |item|
        key = transaction_key(item)
        next if existing.include?(key)

        existing << key
        items_to_create << item
      end

      return OpenStruct.new(batch: nil, created_transactions: []) if items_to_create.empty?

      batch_attrs = { user: @user }
      if single_month_range?(range)
        batch_attrs[:period_month] = range[:start_date].beginning_of_month
      else
        batch_attrs[:range_start_date] = range[:start_date]
        batch_attrs[:range_end_date] = range[:end_date]
      end

      batch = BillTransactionBatch.create!(batch_attrs)

      created = []
      Transaction.transaction do
        items_to_create.each do |item|
          created << Transaction.create!(
            account: item.account,
            trx_date: item.trx_date,
            description: item.description,
            amount: item.amount,
            trx_type: item.trx_type,
            pending: true,
            bill_transaction_batch: batch,
            batch_reference: batch.reference
          )
        end

        batch.update!(
          transactions_count: created.size,
          total_amount: created.sum(&:amount)
        )
      end

      OpenStruct.new(batch: batch, created_transactions: created)
    end

    private

    def occurrences_for_bill(bill, range)
      start_date = range[:start_date]
      end_date = range[:end_date]

      occurrences = []
      month_cursor = start_date.beginning_of_month
      while month_cursor <= end_date
        bill.occurrences_for_month(month_cursor).each do |date|
          next if date < start_date || date > end_date

          occurrences << PreviewItem.new(
            bill: bill,
            account: bill.account,
            trx_date: date,
            amount: signed_amount(bill),
            description: bill.description
          )
        end
        month_cursor = month_cursor.next_month
      end

      occurrences
    end

    def signed_amount(bill)
      amount = bill.amount.to_d
      bill.bill_type == "income" ? amount : -amount
    end

    def existing_keys(range)
      start_date = range[:start_date]
      end_date = range[:end_date]
      Transaction.joins(:account)
                 .where(accounts: { user_id: @user.id }, trx_date: start_date..end_date)
                 .pluck(:account_id, :trx_date, :description, :amount)
                 .each_with_object(Set.new) do |row, set|
        amount = row[3]
        next if amount.nil?

        set << [row[0], row[1], row[2].to_s.strip, BigDecimal(amount.to_s)]
      end
    end

    def transaction_key(item)
      [item.account.id, item.trx_date, item.description.to_s.strip, item.amount]
    end

    def normalize_range(period_month:, start_date:, end_date:)
      if start_date.present? || end_date.present?
        parsed_start = parse_date(start_date) || Time.zone.today.beginning_of_month
        parsed_end = parse_date(end_date) || parsed_start.end_of_month
        parsed_end = parsed_start if parsed_end < parsed_start
        return { start_date: parsed_start, end_date: parsed_end }
      end

      month_start = normalize_month(period_month)
      { start_date: month_start, end_date: month_start.end_of_month }
    end

    def normalize_month(value)
      return value.to_date.beginning_of_month if value.is_a?(Date) || value.is_a?(Time)

      parsed = Date.strptime(value.to_s, "%Y-%m")
      parsed.beginning_of_month
    rescue ArgumentError
      Time.zone.today.beginning_of_month
    end

    def parse_date(value)
      return value.to_date if value.respond_to?(:to_date)

      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def single_month_range?(range)
      range[:start_date].beginning_of_month == range[:end_date].end_of_month
    end
  end
end


