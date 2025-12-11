# frozen_string_literal: true

class CategoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_category, only: :destroy
  before_action :refresh_categories, only: %i[index new create destroy]

  def index
    @category = Category.new
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

  def destroy
    @category.destroy
    refresh_categories
    respond_to do |format|
      format.html { redirect_back fallback_location: categories_path, notice: "Category removed." }
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
                                .select("categories.*, COUNT(transactions.id) AS transactions_count")
                                .group("categories.id")
  end
end

