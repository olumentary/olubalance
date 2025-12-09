# frozen_string_literal: true

class StashesController < ApplicationController
  before_action :authenticate_user!
  before_action :find_account
  before_action :set_stash, only: %i[show edit update destroy]

  # GET /stashes/1
  def show
    @stash_entries = @stash.stash_entries.decorate
  end

  # GET /stashes/new
  def new
    @stash = @account.stashes.build.decorate
  end

  # GET /stashes/1/edit
  def edit
  end

  # POST /stashes
  def create
    @stash = @account.stashes.build(stash_params).decorate

    if @stash.save
      redirect_to account_stash_path(id: @stash.id), notice: "Stash was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /stashes/1
  def update
    if @stash.update(stash_params)
      redirect_to account_stash_path(id: @stash.id), notice: "Stash was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /stashes/1
  def destroy
    @stash.destroy
    redirect_to account_transactions_path(@account), notice: "Stash was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_stash
    @stash = @account.stashes.find(params[:id])
    @stash = @stash.decorate unless action_name == "destroy"
  end

  def find_account
    @account = current_user.accounts.find(params[:account_id]).decorate
    respond_to do |format|
      if @account.active?
        format.html
      else
        format.html { redirect_to accounts_inactive_path, notice: "Account is inactive" }
      end
    end
  end

  # Only allow a trusted parameter "white list" through.
  def stash_params
    params.require(:stash).permit(:name, :description, :goal)
  end
end
