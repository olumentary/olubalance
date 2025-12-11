# frozen_string_literal: true

class CategorySuggester
  Suggestion = Struct.new(:category, :confidence, :source, keyword_init: true)

  def initialize(user:, ai_client: AiCategoryClient.new)
    @user = user
    @ai_client = ai_client
  end

  def suggest(description)
    lookup_suggestion = suggest_from_lookup(description)
    return lookup_suggestion if lookup_suggestion

    normalized_description = CategoryLookup.normalize(description)
    return if normalized_description.blank?

    @ai_client.suggest(description: normalized_description, categories: available_categories)
  end

  private

  attr_reader :user

  def available_categories
    @available_categories ||= Category.for_user(user).ordered
  end

  def suggest_from_lookup(description)
    lookup = CategoryLookup.suggest_for(user: user, description: description)
    return unless lookup

    category = lookup.category
    return unless category

    confidence = [0.6 + Math.log(1 + lookup.usage_count) / 5.0, 0.95].min
    Suggestion.new(category: category, confidence: confidence, source: :lookup)
  end
end

