# frozen_string_literal: true

class TransfersController < ApplicationController
  before_action :authenticate_user!

  # Transfer to another account - creates appropriate transaction records for each account
  def create
    # Scope both account lookups through current_user — these raise
    # ActiveRecord::RecordNotFound (→ 404) if either account belongs to
    # someone else, which is the IDOR boundary.
    source = current_user.accounts.find(params[:transfer_from_account])
    target = current_user.accounts.find(params[:transfer_to_account])

    transfer = PerformTransfer.new(
      source.id,
      target.id,
      params[:transfer_amount],
      params[:transfer_date]
    )

    if transfer.do_transfer
      redirect_to account_transactions_path(source.id), notice: "Transfer successful."
    else
      redirect_to account_transactions_path(source.id), notice: "Transfer failed."
    end
  end

  private

  def transfer_params
    params.require(:transfer).permit(
      :transfer_from_account,
      :transfer_to_account,
      :transfer_amount,
      :transfer_date
    )
  end
end
