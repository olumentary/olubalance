# frozen_string_literal: true

class AiCategoryClient
  DEFAULT_MODEL = ENV.fetch("OPENAI_MODEL", "gpt-4o-mini")

  def initialize(client: default_client)
    @client = client
  end

  def suggest(description:, categories:)
    return if client.nil? || categories.blank?

    response = client.chat(
      parameters: {
        model: DEFAULT_MODEL,
        temperature: 0.2,
        messages: build_prompt(description, categories)
      }
    )

    content = response.dig("choices", 0, "message", "content").to_s
    parsed = parse_response(content, categories)
    return unless parsed&.dig(:category)

    CategorySuggester::Suggestion.new(
      category: parsed[:category],
      confidence: parsed[:confidence],
      source: :ai
    )
  rescue StandardError => e
    Rails.logger.error("AI category suggestion failed: #{e.message}")
    nil
  end

  private

  attr_reader :client

  def build_prompt(description, categories)
    names = categories.map(&:name).uniq
    [
      {
        role: "system",
        content: "You classify bank transactions into one of the provided categories. Respond ONLY with JSON: {\"category\":\"name\",\"confidence\":0.0-1.0}. Use an existing category name exactly. Confidence reflects how sure you are."
      },
      {
        role: "user",
        content: "Description: #{description}\nCategories: #{names.join(', ')}"
      }
    ]
  end

  def parse_response(content, categories)
    data = parse_json(content)
    if data
      matched_category = match_category(data["category"], categories)
      return { category: matched_category, confidence: clamp_confidence(data["confidence"]) } if matched_category
    end

    matched_category = match_category(content, categories)
    return { category: matched_category, confidence: 0.5 } if matched_category
  end

  def parse_json(content)
    JSON.parse(content)
  rescue JSON::ParserError
    nil
  end

  def match_category(name, categories)
    return if name.blank?
    categories.find { |category| category.name.casecmp?(name.to_s.strip) }
  end

  def clamp_confidence(value)
    number = value.to_f
    return 0.0 if number.nan?

    [[number, 1.0].min, 0.0].max
  end

  def default_client
    return unless ENV["OPENAI_API_KEY"].present?

    OpenAI::Client.new
  end
end

