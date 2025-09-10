# frozen_string_literal: true

module DocumentsHelper
  def sort_direction(column)
    current_sort = params[:sort]
    current_direction = params[:direction]
    
    if current_sort == column
      current_direction == 'asc' ? 'desc' : 'asc'
    else
      'asc'
    end
  end
end 