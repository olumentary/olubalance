# frozen_string_literal: true

module TransactionsHelper
  include Pagy::Frontend

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
