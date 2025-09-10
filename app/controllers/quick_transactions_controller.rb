class QuickTransactionsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_user_accounts

  def new
    @transaction = Transaction.new
  end

  def create
    @transaction = Transaction.new(transaction_params)
    @transaction.pending = true
    @transaction.trx_date = Date.current
    @transaction.quick_receipt = true

    if @transaction.save
      redirect_to account_transactions_path(@transaction.account), notice: "Receipt uploaded successfully. You can now fill in the details."
    else
      load_user_accounts
      render :new, status: :unprocessable_entity
    end
  end

  private

  def load_user_accounts
    @user_accounts = current_user.accounts.where(active: true).order(:name).decorate
  end

  def transaction_params
    params.require(:transaction).permit(:account_id, { attachments: [] })
  end
end
