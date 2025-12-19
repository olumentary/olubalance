# frozen_string_literal: true

class MatchingRulesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_matching_rule, only: %i[show edit update destroy]
  before_action :load_categories, only: %i[index new create edit update]

  def index
    @matching_rules = current_user.category_lookups
                                  .includes(:category)
                                  .then { |scope| filter_by_description(scope) }
                                  .then { |scope| filter_by_category(scope) }
                                  .order(last_used_at: :desc, usage_count: :desc)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    redirect_to edit_matching_rule_path(@matching_rule)
  end

  def new
    @matching_rule = current_user.category_lookups.new
  end

  def create
    @matching_rule = current_user.category_lookups.new(matching_rule_params)
    @matching_rule.usage_count ||= 1
    @matching_rule.last_used_at ||= Time.current

    if @matching_rule.save
      respond_to do |format|
        format.html do
          redirect_to matching_rules_path(description: params[:description], category_id: params[:category_id]),
                      notice: "Matching rule created."
        end
        format.turbo_stream do
          redirect_to matching_rules_path(format: :html, description: params[:description], category_id: params[:category_id]),
                      notice: "Matching rule created.",
                      status: :see_other
        end
      end
    else
      load_categories
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @matching_rule.update(matching_rule_params)
      respond_to do |format|
        format.html do
          redirect_to matching_rules_path(description: params[:description], category_id: params[:category_id]),
                      notice: "Matching rule updated."
        end
        format.turbo_stream do
          redirect_to matching_rules_path(format: :html, description: params[:description], category_id: params[:category_id]),
                      notice: "Matching rule updated.",
                      status: :see_other
        end
      end
    else
      load_categories
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @matching_rule.destroy
    respond_to do |format|
      format.html { redirect_to matching_rules_path, notice: "Matching rule deleted." }
      format.turbo_stream
    end
  end

  private

  def matching_rule_params
    params.require(:category_lookup).permit(:description_norm, :category_id)
  end

  def set_matching_rule
    @matching_rule = current_user.category_lookups.find(params[:id])
  end

  def load_categories
    @categories = Category.for_user(current_user).ordered
  end

  def filter_by_description(scope)
    return scope if params[:description].blank?

    scope.where("description_norm ILIKE ?", "%#{params[:description].downcase}%")
  end

  def filter_by_category(scope)
    return scope if params[:category_id].blank?

    scope.where(category_id: params[:category_id])
  end
end

