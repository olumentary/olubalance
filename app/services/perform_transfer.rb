# frozen_string_literal: true

# Transfer money between accounts by creating a
# debit transaction in the originating account,
# and a credit transaction in the target acccount
class PerformTransfer
  def initialize(source_account_id, target_account_id, amount, date = Time.current)
    @source_account = Account.find(source_account_id).decorate
    @target_account = Account.find(target_account_id).decorate
    @amount = amount
    @date = date
  end

  def do_transfer
    Transaction.transaction do
      source_transaction = create_source_transaction!
      target_transaction = create_target_transaction!
      
      # Link the transactions together
      source_transaction.update_column(:counterpart_transaction_id, target_transaction.id)
      target_transaction.update_column(:counterpart_transaction_id, source_transaction.id)
    end
  end

  def create_source_transaction!
    transaction = Transaction.new
    transaction.trx_type = "debit"
    transaction.trx_date = @date
    transaction.account_id = @source_account.id
    transaction.description = "Transfer to " + @target_account.name
    transaction.amount = @amount.to_d.abs
    transaction.locked = true
    transaction.transfer = true
    transaction.save!
    transaction
  end

  def create_target_transaction!
    transaction = Transaction.new
    transaction.trx_type = "credit"
    transaction.trx_date = @date
    transaction.account_id = @target_account.id
    transaction.description = "Transfer from " + @source_account.name
    transaction.amount = @amount.to_d.abs
    transaction.locked = true
    transaction.transfer = true
    transaction.save!
    transaction
  end
end
