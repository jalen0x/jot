require "base64"
require "net/http"

class ReceiptRecognitionClient
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ResponseError < Error; end

  DEFAULT_BASE_URL = "https://api.openai.com/v1"

  def initialize(api_key: ENV["OPENAI_API_KEY"], model: ENV["OPENAI_RECEIPT_RECOGNITION_MODEL"], base_url: ENV.fetch("OPENAI_BASE_URL", DEFAULT_BASE_URL), timeout: 30)
    @api_key = api_key.to_s
    @model = model.to_s
    @base_url = base_url.to_s
    @timeout = timeout
  end

  def recognize(image_bytes:, content_type:)
    ensure_configured!

    response = post_json(responses_uri, request_body(image_bytes:, content_type:))
    parse_json_output(response)
  end

  private

  def ensure_configured!
    raise ConfigurationError, "OPENAI_API_KEY is required" if @api_key.blank?
    raise ConfigurationError, "OPENAI_RECEIPT_RECOGNITION_MODEL is required" if @model.blank?
  end

  def responses_uri
    URI.join(normalized_base_url, "responses")
  end

  def normalized_base_url
    @base_url.end_with?("/") ? @base_url : "#{@base_url}/"
  end

  def post_json(uri, body)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    request.body = JSON.generate(body)

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", read_timeout: @timeout, open_timeout: @timeout) do |http|
      http.request(request)
    end

    raise ResponseError, "recognition provider returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue JSON::ParserError => error
    raise ResponseError, "recognition provider returned invalid JSON: #{error.message}"
  end

  def request_body(image_bytes:, content_type:)
    {
      model: @model,
      input: [
        {
          role: "user",
          content: [
            { type: "input_text", text: prompt },
            { type: "input_image", image_url: data_url(image_bytes:, content_type:) }
          ]
        }
      ],
      text: {
        format: {
          type: "json_schema",
          name: "receipt_recognition",
          strict: true,
          schema: receipt_schema
        }
      }
    }
  end

  def prompt
    <<~PROMPT.squish
      Extract receipt data for a personal finance transaction. Return only the requested JSON fields. Use an empty string when text is unknown, 0 when the total amount is unknown, and ISO 4217 currency codes when visible.
    PROMPT
  end

  def data_url(image_bytes:, content_type:)
    "data:#{content_type};base64,#{Base64.strict_encode64(image_bytes)}"
  end

  def receipt_schema
    {
      type: "object",
      additionalProperties: false,
      properties: {
        merchant_name: { type: "string" },
        transaction_date: { type: "string" },
        total_amount: { type: "number" },
        currency_code: { type: "string" },
        category_hint: { type: "string" },
        notes: { type: "string" }
      },
      required: %w[merchant_name transaction_date total_amount currency_code category_hint notes]
    }
  end

  def parse_json_output(response)
    text = response["output_text"] || output_text_from_items(response.fetch("output", []))
    raise ResponseError, "recognition provider response did not include output text" if text.blank?

    JSON.parse(text)
  rescue JSON::ParserError => error
    raise ResponseError, "recognition provider output was not valid JSON: #{error.message}"
  end

  def output_text_from_items(items)
    items.each do |item|
      Array(item["content"]).each do |content|
        return content["text"] if content["type"] == "output_text" && content["text"].present?
      end
    end
    nil
  end
end
