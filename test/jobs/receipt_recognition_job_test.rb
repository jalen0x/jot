require "test_helper"
require "turbo/broadcastable/test_helper"
require "webmock/minitest"

class ReceiptRecognitionJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper

  test "updates a recognition with parsed receipt data" do
    recognition = create_recognition
    client = FakeReceiptRecognitionClient.new(result: { "merchant_name" => "Cafe", "total_amount" => 12.5 })

    ReceiptRecognitionProcessor.new(client: client).process(receipt_recognition: recognition)

    assert_predicate recognition.reload, :succeeded?
    assert_equal({ "merchant_name" => "Cafe", "total_amount" => 12.5 }, recognition.result_json)
    assert_nil recognition.error_message
    assert_equal 1, client.open_transaction_count
  end

  test "broadcasts recognition state changes" do
    recognition = create_recognition
    client = FakeReceiptRecognitionClient.new(result: { "merchant_name" => "Cafe", "total_amount" => 12.5 })

    streams = capture_turbo_stream_broadcasts(recognition) do
      ReceiptRecognitionProcessor.new(client: client).process(receipt_recognition: recognition)
    end

    assert_equal %w[replace replace], streams.map { |stream| stream["action"] }
    assert_equal [ ActionView::RecordIdentifier.dom_id(recognition) ] * 2, streams.map { |stream| stream["target"] }
  end

  test "marks the recognition failed and surfaces client errors" do
    recognition = create_recognition
    client = FakeReceiptRecognitionClient.new(error: ReceiptRecognitionClient::Error.new("provider unavailable"))

    assert_raises(ReceiptRecognitionClient::Error) do
      ReceiptRecognitionProcessor.new(client: client).process(receipt_recognition: recognition)
    end

    assert_predicate recognition.reload, :failed?
    assert_equal "provider unavailable", recognition.error_message
  end

  test "job loads the recognition and processes it" do
    recognition = create_recognition
    with_openai_env do
      stub_receipt_response
      ReceiptRecognitionJob.perform_now(recognition.id)
    end

    assert_predicate recognition.reload, :succeeded?
    assert_equal "Cafe", recognition.result_json.fetch("merchant_name")
  end

  private

  def create_recognition
    recognition = ReceiptRecognition.new(user: create(:user), status: :pending)
    recognition.image.attach(io: StringIO.new("receipt"), filename: "receipt.png", content_type: "image/png")
    recognition.save!
    recognition
  end

  class FakeReceiptRecognitionClient
    attr_reader :open_transaction_count

    def initialize(result: nil, error: nil)
      @result = result
      @error = error
    end

    def recognize(image_bytes:, content_type:)
      @open_transaction_count = ActiveRecord::Base.connection.open_transactions
      raise @error if @error

      @result
    end
  end

  def with_openai_env
    previous_api_key = ENV["OPENAI_API_KEY"]
    previous_model = ENV["OPENAI_RECEIPT_RECOGNITION_MODEL"]
    ENV["OPENAI_API_KEY"] = "test-key"
    ENV["OPENAI_RECEIPT_RECOGNITION_MODEL"] = "vision-model"
    yield
  ensure
    ENV["OPENAI_API_KEY"] = previous_api_key
    ENV["OPENAI_RECEIPT_RECOGNITION_MODEL"] = previous_model
  end

  def stub_receipt_response
    stub_request(:post, "https://api.openai.com/v1/responses").to_return(
      status: 200,
      headers: { "Content-Type" => "application/json" },
      body: {
        output: [
          {
            content: [
              {
                type: "output_text",
                text: { merchant_name: "Cafe", transaction_date: "", total_amount: 12.5, currency_code: "USD", category_hint: "", notes: "" }.to_json
              }
            ]
          }
        ]
      }.to_json
    )
  end
end
