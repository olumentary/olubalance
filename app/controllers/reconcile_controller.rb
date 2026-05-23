# frozen_string_literal: true

# Weekly catch-up: walks the user through every account that hasn't been
# reviewed for the current Sunday–Saturday week. "Reviewed" means either a
# real transaction was added or the user explicitly clicked
# "Mark reviewed for the week" — both stamp `last_transaction_on`.
class ReconcileController < ApplicationController
  before_action :authenticate_user!

  def show
    accounts = current_user.accounts.active.decorate
    @accounts_to_review = accounts
                          .reject { |a| a.reviewed_this_week? }
                          .sort_by { |a| [ a.weekly_review_sort_key, -(a.days_since_last_transaction || 99_999) ] }
    @total_count = @accounts_to_review.size
    @user = current_user.decorate
  end

  def mark_current
    @account = current_user.accounts.find(params[:account_id])
    @account.update_columns(last_transaction_on: Date.current)
    @account = @account.decorate

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to reconcile_path }
    end
  end
end
