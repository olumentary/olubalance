# frozen_string_literal: true

module SearchHelper
  def search_sort_indicator(column, current_sort, current_dir)
    return "" unless column == current_sort

    current_dir == "asc" ? " \u25B2" : " \u25BC"
  end
end
