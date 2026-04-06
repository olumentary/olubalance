# frozen_string_literal: true

class ReceiptOcrClient
  DEFAULT_MODEL = ENV.fetch("OPENAI_VISION_MODEL", "gpt-4o")

  OcrResult = Struct.new(:description, :date, :amount, :trx_type, keyword_init: true)

  def initialize(client: default_client)
    @client = client
  end

  def process(attachments:)
    if client.nil?
      Rails.logger.info("Receipt OCR skipped: client not configured")
      return
    end

    image_attachment = attachments.find { |a| a.content_type.start_with?("image/") }
    if image_attachment.nil?
      Rails.logger.info("Receipt OCR skipped: no image attachment found")
      return
    end

    base64_image = encode_attachment(image_attachment)
    return unless base64_image

    response = client.chat(
      parameters: {
        model: DEFAULT_MODEL,
        temperature: 0.1,
        max_tokens: 300,
        messages: build_prompt(base64_image, image_attachment.content_type)
      }
    )

    content = response.dig("choices", 0, "message", "content").to_s
    Rails.logger.info("Receipt OCR response: #{content}")
    parse_response(content)
  rescue Faraday::Error => e
    status = e.response&.dig(:status)
    log_http_error(e, status)
    nil
  rescue StandardError => e
    Rails.logger.error("Receipt OCR failed: #{e.class} #{e.message}")
    nil
  end

  private

  attr_reader :client

  def encode_attachment(attachment)
    # Download the blob and base64-encode it for the vision API
    blob_data = attachment.blob.download
    Base64.strict_encode64(blob_data)
  rescue StandardError => e
    Rails.logger.error("Receipt OCR: failed to download attachment #{attachment.id}: #{e.message}")
    nil
  end

  def build_prompt(base64_image, content_type)
    [
      {
        role: "system",
        content: <<~PROMPT.strip
          You are a receipt OCR assistant. Extract key fields from the receipt image and respond ONLY with valid JSON in this exact format:
          {"description":"merchant or store name","date":"YYYY-MM-DD","amount":"0.00","trx_type":"debit"}

          Rules:
          - description: the merchant/vendor name (e.g. "Starbucks", "Amazon", "Shell")
          - date: the transaction date in YYYY-MM-DD format; if unclear use today's date
          - amount: the total charged amount as a positive decimal string with 2 decimal places (e.g. "12.50")
          - trx_type: "debit" for a purchase/expense, "credit" for a refund/return
          - If a field cannot be determined, use null for that field
          - Respond with JSON only, no other text
        PROMPT
      },
      {
        role: "user",
        content: [
          {
            type: "image_url",
            image_url: {
              url: "data:#{content_type};base64,#{base64_image}",
              detail: "high"
            }
          }
        ]
      }
    ]
  end

  def parse_response(content)
    # Strip markdown code fences if present
    clean = content.gsub(/\A```(?:json)?\s*/, "").gsub(/\s*```\z/, "").strip
    data = JSON.parse(clean)

    description = data["description"].presence
    date_str    = parse_date(data["date"])
    amount      = parse_amount(data["amount"])
    trx_type    = data["trx_type"].to_s.downcase == "credit" ? "credit" : "debit"

    OcrResult.new(
      description: description,
      date:        date_str,
      amount:      amount,
      trx_type:    trx_type
    )
  rescue JSON::ParserError => e
    Rails.logger.warn("Receipt OCR JSON parse error: #{e.message} content=#{content}")
    nil
  end

  def parse_date(value)
    return nil if value.blank?

    Date.parse(value.to_s).strftime("%Y-%m-%d")
  rescue ArgumentError, TypeError
    nil
  end

  def parse_amount(value)
    return nil if value.blank? || value.to_s.strip == "null"

    cleaned = value.to_s.gsub(/[^\d.]/, "")
    parsed  = cleaned.to_f
    return nil if parsed.zero? && cleaned !~ /\A0+\.?0*\z/

    format("%.2f", parsed)
  end

  def default_client
    return unless ENV["OPENAI_API_KEY"].present?

    OpenAI::Client.new
  end

  def log_http_error(error, status)
    Rails.logger.warn("Receipt OCR HTTP error status=#{status.inspect} class=#{error.class} message=#{error.message}")
  end
end
