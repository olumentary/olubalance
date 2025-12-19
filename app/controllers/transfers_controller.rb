# frozen_string_literal: true

class TransfersController < ApplicationController
  # Transfer to another account - creates appropriate transaction records for each account
  def create
    transfer = PerformTransfer.new(
      params[:transfer_from_account],
      params[:transfer_to_account],
      params[:transfer_amount],
      params[:transfer_date]
    )

    if transfer.do_transfer
      redirect_to account_transactions_path(params[:transfer_from_account]), notice: "Transfer successful."
    else
      redirect_to account_transactions_path(params[:transfer_from_account]), notice: "Transfer failed."
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
