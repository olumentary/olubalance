# frozen_string_literal: true

class CategoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_category, only: %i[show edit update destroy]
  before_action :refresh_categories, only: %i[index new create edit update destroy]

  def index
    @category = Category.new
  end

  def show
    redirect_to edit_category_path(@category)
  end

  def new
    @category = Category.new
  end

  def create
    @category = current_user.categories.new(category_params.merge(kind: :custom))

    if @category.save
      refresh_categories
      @selected_category_id = @category.id
      respond_to do |format|
        format.html { redirect_back fallback_location: categories_path, notice: "Category created." }
        format.turbo_stream
        format.json { render json: { id: @category.id, name: @category.name }, status: :created }
      end
    else
      refresh_categories
      respond_to do |format|
        format.html { redirect_back fallback_location: categories_path, alert: @category.errors.full_messages.to_sentence }
        format.turbo_stream { render :create, status: :unprocessable_entity }
        format.json { render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @category.global?
      # For global categories, create a custom copy for this user and hide the original
      handle_global_category_rename
    else
      # For custom categories, update directly
      if @category.update(category_params)
        respond_to do |format|
          format.html { redirect_to categories_path, notice: "Category updated." }
          format.turbo_stream { redirect_to categories_path, notice: "Category updated." }
        end
      else
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
          format.turbo_stream { render :edit, status: :unprocessable_entity }
        end
      end
    end
  end

  def destroy
    if @category.global?
      # For global categories, hide it for the current user only
      handle_global_category_delete
    else
      # For custom categories, delete completely
      handle_custom_category_delete
    end

    refresh_categories
    respond_to do |format|
      format.html { redirect_to categories_path, notice: "Category removed." }
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private

  def category_params
    params.require(:category).permit(:name)
  end

  def category_scope
    Category.for_user(current_user)
  end

  def set_category
    @category = category_scope.find(params[:id])
  end

  def refresh_categories
    @categories = category_scope.ordered
    @categories_with_counts = @categories
                                .left_outer_joins(:transactions)
                                .joins("LEFT OUTER JOIN accounts ON transactions.account_id = accounts.id AND accounts.user_id = #{current_user.id}")
                                .select("categories.*, COUNT(CASE WHEN accounts.user_id = #{current_user.id} THEN transactions.id END) AS transactions_count")
                                .group("categories.id")
  end

  def handle_global_category_rename
    new_name = category_params[:name]

    # Check if the user already has a category with this name
    if current_user.categories.exists?(["LOWER(name) = ?", new_name.downcase.squish])
      @category.errors.add(:name, "already exists")
      render :edit, status: :unprocessable_entity
      return
    end

    # Create a new custom category for this user
    new_category = current_user.categories.create!(name: new_name, kind: :custom)

    # Reassign this user's transactions from the global category to the new one
    user_transaction_ids = Transaction.joins(:account)
                                       .where(accounts: { user_id: current_user.id })
                                       .where(category_id: @category.id)
                                       .pluck(:id)
    Transaction.where(id: user_transaction_ids).update_all(category_id: new_category.id)

    # Reassign this user's lookups to the new category
    current_user.category_lookups.where(category_id: @category.id).update_all(category_id: new_category.id)

    # Hide the original global category for this user
    HiddenCategory.find_or_create_by!(user: current_user, category: @category)

    respond_to do |format|
      format.html { redirect_to categories_path, notice: "Category renamed (created your own copy)." }
      format.turbo_stream { redirect_to categories_path, notice: "Category renamed (created your own copy)." }
    end
  end

  def handle_global_category_delete
    # Set category to NULL for this user's transactions
    user_transaction_ids = Transaction.joins(:account)
                                       .where(accounts: { user_id: current_user.id })
                                       .where(category_id: @category.id)
                                       .pluck(:id)
    Transaction.where(id: user_transaction_ids).update_all(category_id: nil)

    # Delete this user's lookups for this category
    current_user.category_lookups.where(category_id: @category.id).destroy_all

    # Hide the global category for this user
    HiddenCategory.find_or_create_by!(user: current_user, category: @category)
  end

  def handle_custom_category_delete
    # Set category to NULL for transactions using this category
    @category.transactions.update_all(category_id: nil)

    # Delete lookups for this category
    @category.category_lookups.destroy_all

    # Delete the category
    @category.destroy
  end
end
