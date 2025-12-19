# frozen_string_literal: true

module CategoriesHelper
  def category_options(categories, selected = nil)
    blank_option = options_for_select([["Uncategorized", nil]], selected)
    category_options = options_from_collection_for_select(categories, :id, :name, selected)
    blank_option + category_options
  end

  def category_kind_label(category)
    category.global? ? "Standard" : "Custom"
  end
end

