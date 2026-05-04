require "test_helper"

class ReceiptRecognitionTest < ActiveSupport::TestCase
  test "requires an attached image" do
    recognition = ReceiptRecognition.new(user: create(:user), status: :pending)

    assert_not recognition.valid?
    assert_includes recognition.errors[:image], "must be attached"
  end

  test "serializes safe result data" do
    recognition = ReceiptRecognition.new(user: create(:user), status: :succeeded, result_json: { "merchant_name" => "Cafe", "total_amount" => 12.5 })
    recognition.image.attach(io: StringIO.new("receipt"), filename: "receipt.png", content_type: "image/png")
    recognition.save!

    json = recognition.as_json

    assert_equal recognition.to_param, json.fetch(:id)
    assert_equal "succeeded", json.fetch(:status)
    assert_equal({ "merchant_name" => "Cafe", "total_amount" => 12.5 }, json.fetch(:result))
    refute_includes json.keys, :user_id
  end
end
