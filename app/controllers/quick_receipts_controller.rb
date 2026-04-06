# frozen_string_literal: true

class QuickReceiptsController < ApplicationController
  before_action :authenticate_user!

  def index
    quick_receipts = Transaction
      .quick_receipts
      .joins(:account)
      .where(accounts: { user_id: current_user.id, active: true })
      .with_attached_attachments
      .includes(:category, :account)
      .order('accounts.name ASC, transactions.created_at ASC')
      .decorate

    @quick_receipt_count = quick_receipts.size
    @quick_receipts_by_account = quick_receipts.group_by(&:account)
    @categories = Category.for_user(current_user).ordered
  end
end
