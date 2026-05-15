# frozen_string_literal: true

class StashEntriesController < ApplicationController
  before_action :authenticate_user!
  before_action :find_stash

  # GET /stashes/new
  def new
    @stash_entry = @stash.stash_entries.build.decorate
    @stash_entry.stash_action = params[:stash_action]
  end

  # POST /stashes
  def create
    @stash_entry = @stash.stash_entries.build(stash_entry_params).decorate
    if @stash_entry.save
      redirect_to account_transactions_path, notice: "Stash entry was successfully created."
    else
      render :new
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def find_stash
    # Scope through current_user → account → stashes so that another user's
    # stash returns 404 (RecordNotFound) instead of being mutable.
    account = current_user.accounts.find(params[:account_id])
    @stash = account.stashes.find(params[:stash_id]).decorate
    respond_to do |format|
      format.html
    end
  end

  # Only allow a trusted parameter "white list" through.
  def stash_entry_params
    params.require(:stash_entry).permit(:stash_action, :amount, :stash_entry_date)
  end
end
