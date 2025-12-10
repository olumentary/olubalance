# frozen_string_literal: true

module Transactions
  class BatchesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_batch, only: %i[show destroy]
    before_action :set_bill, only: %i[new create]
    helper_method :generation_params

    def index
      @batches = current_user.bill_transaction_batches.includes(:transactions).ordered
    end

    def show
      @transactions = @batch.transactions.includes(:account).order(:trx_date, :id)
    end

    def new
      @range = if params[:month].present? || params[:start_date].present? || params[:end_date].present?
                 parsed_range
               else
                 default_range
               end
      @preview_items = generator.preview(start_date: @range[:start_date], end_date: @range[:end_date], bill: @bill)

      render layout: false if turbo_frame_request?
    end

    def create
      range = parsed_range
      result = generator.generate!(start_date: range[:start_date], end_date: range[:end_date], bill: @bill)

      if result.batch.present? && result.created_transactions.any?
        flash[:notice] = "#{result.created_transactions.size} pending transactions generated."
        flash[:undo_batch_id] = result.batch.id
      else
        flash[:alert] = "No pending transactions were generated for the selected dates."
      end

      redirect_to bills_path(view: params[:view])
    end

    def destroy
      non_pending_count = @batch.transactions.where.not(pending: true).count

      if non_pending_count.positive?
        redirect_back fallback_location: bills_path, alert: "Cannot undo because some transactions were already reviewed." and return
      end

      Transaction.transaction do
        @batch.transactions.find_each(&:destroy!)
        @batch.destroy!
      end

      redirect_back fallback_location: bills_path, notice: "Generated transactions were undone."
    end

    private

    def generator
      @generator ||= BillTransactions::Generator.new(user: current_user)
    end

    def generation_params(range, bill)
      params_hash = { start_date: range[:start_date], end_date: range[:end_date] }
      params_hash[:bill_id] = bill.id if bill.present?
      params_hash[:view] = params[:view] if params[:view].present?
      params_hash
    end

    def parsed_range
      if params[:month].present?
        month = parse_month(params[:month])
        return { start_date: month.beginning_of_month, end_date: month.end_of_month }
      end

      start_date = parse_date(params[:start_date]) || Time.zone.today.beginning_of_month
      end_date = parse_date(params[:end_date]) || start_date.end_of_month
      end_date = start_date if end_date < start_date
      { start_date:, end_date: }
    end

    def set_batch
      @batch = current_user.bill_transaction_batches.find(params[:id])
    end

    def set_bill
      return unless params[:bill_id].present?

      @bill = current_user.bills.find(params[:bill_id])
    end

    def default_range
      if @bill
        date = next_occurrence_for(@bill)
        start_date = date.beginning_of_month
        end_date = start_date.end_of_month
        { start_date:, end_date: }
      else
        today = Time.zone.today
        { start_date: today.beginning_of_month, end_date: today.end_of_month }
      end
    end

    def parse_month(value)
      Date.strptime(value.to_s, "%Y-%m")
    rescue ArgumentError
      Time.zone.today
    end

    def parse_date(value)
      return value.to_date if value.respond_to?(:to_date)

      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def next_occurrence_for(bill)
      reference = Time.zone.today.beginning_of_month
      12.times do
        occurrences = bill.occurrences_for_month(reference)
        return occurrences.first if occurrences.any?

        reference = reference.next_month
      end

      Time.zone.today
    end
  end
end


