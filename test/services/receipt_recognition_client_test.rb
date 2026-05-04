require "test_helper"
require "webmock/minitest"

class ReceiptRecognitionClientTest < ActiveSupport::TestCase
  test "posts receipt image to the Responses API and parses JSON output" do
    stub = stub_request(:post, "https://api.openai.com/v1/responses")
      .with do |request|
        body = JSON.parse(request.body)
        image = body.fetch("input").first.fetch("content").find { |content| content.fetch("type") == "input_image" }

        request.headers["Authorization"] == "Bearer test-key" &&
          body.fetch("model") == "vision-model" &&
          image.fetch("image_url").start_with?("data:image/png;base64,") &&
          body.dig("text", "format", "type") == "json_schema"
      end
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          output: [
            {
              content: [
                {
                  type: "output_text",
                  text: { merchant_name: "Cafe", total_amount: 12.5, currency_code: "USD" }.to_json
                }
              ]
            }
          ]
        }.to_json
      )

    result = ReceiptRecognitionClient.new(api_key: "test-key", model: "vision-model").recognize(
      image_bytes: "receipt-bytes",
      content_type: "image/png"
    )

    assert_requested stub
    assert_equal "Cafe", result.fetch("merchant_name")
    assert_equal 12.5, result.fetch("total_amount")
    assert_equal "USD", result.fetch("currency_code")
  end

  test "requires api key and model" do
    client = ReceiptRecognitionClient.new(api_key: "", model: "")

    assert_raises(ReceiptRecognitionClient::ConfigurationError) do
      client.recognize(image_bytes: "receipt", content_type: "image/png")
    end
  end
end
