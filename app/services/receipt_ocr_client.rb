# frozen_string_literal: true

class ReceiptOcrClient
  DEFAULT_MODEL = ENV.fetch("OPENAI_VISION_MODEL", "gpt-4o")

  OcrResult = Struct.new(:description, :date, :date_confidence, :amount, :trx_type, keyword_init: true)

  DATE_WINDOW_DAYS = 60

  def initialize(client: default_client)
    @client = client
  end

  def process(attachments:, reference_date: Date.current)
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
    parse_response(content, reference_date: reference_date)
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
          {"description":"merchant or store name","date":"YYYY-MM-DD","date_confidence":"high","amount":"0.00","trx_type":"debit"}

          Rules:
          - description: the merchant/vendor name (e.g. "Starbucks", "Amazon", "Shell")
          - date: the transaction date in YYYY-MM-DD format. Only return a date if it is clearly and unambiguously visible on the receipt. If the date is missing, illegible, cropped, or you are inferring/guessing, use null.
          - date_confidence: "high" only when the full date (year, month, day) is unambiguously legible on the receipt; otherwise "low". Never guess the year — if the year is not printed on the receipt, confidence must be "low".
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

  def parse_response(content, reference_date:)
    # Strip markdown code fences if present
    clean = content.gsub(/\A```(?:json)?\s*/, "").gsub(/\s*```\z/, "").strip
    data = JSON.parse(clean)

    description     = data["description"].presence
    raw_date        = parse_date(data["date"])
    date_confidence = data["date_confidence"].to_s.downcase.presence
    accepted_date   = validate_date(raw_date, date_confidence, reference_date)
    amount          = parse_amount(data["amount"])
    trx_type        = data["trx_type"].to_s.downcase == "credit" ? "credit" : "debit"

    OcrResult.new(
      description:     description,
      date:            accepted_date,
      date_confidence: date_confidence,
      amount:          amount,
      trx_type:        trx_type
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

  # Returns the date string only if the AI is confident AND the date falls in a
  # sane window anchored on reference_date (typically the transaction's
  # created_at). Out-of-window or low-confidence dates are dropped to nil so the
  # caller (Stimulus) leaves the existing trx_date in place.
  def validate_date(date_str, confidence, reference_date)
    return nil if date_str.blank?

    if confidence != "high"
      Rails.logger.info("Receipt OCR date rejected (confidence=#{confidence.inspect}): #{date_str}")
      return nil
    end

    parsed  = Date.parse(date_str)
    floor   = [ Date.current - DATE_WINDOW_DAYS.days, reference_date ].min
    ceiling = Date.current

    if parsed < floor || parsed > ceiling
      Rails.logger.info(
        "Receipt OCR date rejected (out of window): #{date_str} not in [#{floor}..#{ceiling}]"
      )
      return nil
    end

    date_str
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
