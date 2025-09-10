# frozen_string_literal: true

module TransactionsHelper
  include Pagy::Frontend

  def custom_pagination(pagy, account)
    return "" if pagy.pages <= 1

    Rails.logger.info "Custom pagination - Current page: #{pagy.page}, Total pages: #{pagy.pages}, Series: #{pagy.series}"

    # Build base URL with filters preserved
    base_params = {}
    if session["filters"]&.dig("description")&.present?
      base_params[:description] = session["filters"]["description"]
    end
    if session["filters"]&.dig("account_id")&.present?
      base_params[:account_id] = session["filters"]["account_id"]
    end

    html = '<nav class="pagination is-centered" role="navigation" aria-label="pagination">'
    
    # Previous button
    if pagy.prev
      prev_params = base_params.merge(page: pagy.prev)
      html += link_to("Previous", account_transactions_path(account) + "?" + prev_params.to_query, class: "pagination-previous")
    else
      html += '<span class="pagination-previous" disabled>Previous</span>'
    end

    # Next button
    if pagy.next
      next_params = base_params.merge(page: pagy.next)
      html += link_to("Next", account_transactions_path(account) + "?" + next_params.to_query, class: "pagination-next")
    else
      html += '<span class="pagination-next" disabled>Next</span>'
    end

    # Page numbers
    html += '<ul class="pagination-list">'
    
    pagy.series.each do |item|
      if item.is_a?(Integer) || (item.is_a?(String) && item.match?(/\A\d+\z/))
        # Page number - convert to integer for comparison
        page_num = item.to_i
        if page_num == pagy.page
          html += '<li><span class="pagination-link is-current" aria-current="page">' + page_num.to_s + '</span></li>'
        else
          page_params = base_params.merge(page: page_num)
          html += '<li>' + link_to(page_num.to_s, account_transactions_path(account) + "?" + page_params.to_query, class: "pagination-link") + '</li>'
        end
      elsif item == :gap
        html += '<li><span class="pagination-ellipsis">&hellip;</span></li>'
      end
    end
    
    html += '</ul>'
    html += '</nav>'
    
    html.html_safe
  end

  def sort_link(column:, label:)
    direction = column == session["filters"]&.dig("column") ? next_direction : "asc"
    link_to(account_transactions_path(column: column, direction: direction), class: "has-text-white sortable", data: { turbo_action: "replace" }) do
      ('<span class="sortable-column-name">' + label + "</span>").html_safe
    end
  end

  def next_direction
    session["filters"]&.dig("direction") == "asc" ? "desc" : "asc"
  end

  def sort_indicator
    icon = session["filters"]&.dig("direction") == "asc" ? "fa-sort-up" : "fa-sort-down"
    ('<span class="icon is-small" style="display: inline-table">' +
      '<i class="fas ' + icon + '"></i>' +
    "</span>").html_safe
  end

  def sort_indicator_default
    ('<span class="icon is-small" style="display: inline-table">' +
      '<i class="fas fa-sort"></i>' +
    "</span>").html_safe
  end

  def show_sort_indicator_for(column)
    return sort_indicator if session["filters"]&.dig("column") == column

    sort_indicator_default
  end

  def inline_edit_attributes(transaction, field, value)
    return {} unless transaction.pending?
    {
      controller: "inline-edit",
      "inline-edit-url-value": account_transaction_path(id: transaction.id),
      "inline-edit-field-value": field,
      "inline-edit-value-value": value,
      action: "click->inline-edit#showInput"
    }
  end

  def inline_edit_input_attributes(transaction, input_type, value, options = {})
    return unless transaction.pending?
    input_attrs = {
      type: input_type,
      class: "input is-small is-hidden",
      "data-inline-edit-target": "input",
      value: value,
      "data-action": "blur->inline-edit#updateValue keydown->inline-edit#handleKeydown"
    }
    input_attrs.merge!(options)
    input_attrs
  end

  def cell_style(transaction)
    transaction.pending? ? "cursor: pointer;" : ""
  end

  def clickable_class(transaction)
    transaction.pending? ? "is-clickable" : ""
  end

  def formatted_amount_value(transaction)
    return "" unless transaction.amount
    sprintf("%.2f", transaction.amount.abs)
  end
end
