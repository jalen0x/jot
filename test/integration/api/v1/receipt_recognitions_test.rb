require "test_helper"

class ApiV1ReceiptRecognitionsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "creates a pending receipt recognition for the token owner" do
    user = create(:user)
    raw_token = issue_token(user)

    assert_enqueued_jobs 1, only: ReceiptRecognitionJob do
      post api_v1_receipt_recognitions_path,
        params: { receipt_recognition: { image: fixture_file_upload("avatar.png", "image/png") } },
        headers: json_headers(raw_token)
    end

    assert_response :created
    recognition = user.receipt_recognitions.sole
    assert_predicate recognition, :pending?
    assert_predicate recognition.image, :attached?
    recognition_job = enqueued_jobs.select { |job| job.fetch(:job) == ReceiptRecognitionJob }.sole
    assert_equal [ recognition.id ], recognition_job.fetch(:args)

    recognition_json = JSON.parse(response.body).fetch("receipt_recognition")
    assert_equal recognition.to_param, recognition_json.fetch("id")
    assert_equal "pending", recognition_json.fetch("status")
    assert_equal({}, recognition_json.fetch("result"))
    assert_nil recognition_json.fetch("error_message")
    refute_includes recognition_json.keys, "user_id"
  end

  test "shows one receipt recognition for the token owner" do
    user = create(:user)
    recognition = create_recognition(user:, status: :succeeded, result_json: { "merchant_name" => "Cafe", "total_amount" => 12.5 })
    raw_token = issue_token(user)

    get api_v1_receipt_recognition_path(recognition), headers: json_headers(raw_token)

    assert_response :success
    recognition_json = JSON.parse(response.body).fetch("receipt_recognition")
    assert_equal recognition.to_param, recognition_json.fetch("id")
    assert_equal "succeeded", recognition_json.fetch("status")
    assert_equal "Cafe", recognition_json.fetch("result").fetch("merchant_name")
    assert_equal 12.5, recognition_json.fetch("result").fetch("total_amount")
    refute_includes recognition_json.keys, "user_id"
  end

  test "does not show another user's receipt recognition" do
    user = create(:user)
    recognition = create_recognition(user: create(:user))
    raw_token = issue_token(user)

    get api_v1_receipt_recognition_path(recognition), headers: json_headers(raw_token)

    assert_response :not_found
  end

  test "rejects invalid receipt recognition params" do
    user = create(:user)
    raw_token = issue_token(user)

    assert_no_enqueued_jobs only: ReceiptRecognitionJob do
      post api_v1_receipt_recognitions_path,
        params: { receipt_recognition: { image: "" } },
        headers: json_headers(raw_token)
    end

    assert_response :unprocessable_content
    assert_empty user.receipt_recognitions
    assert_match(/Image must be attached/i, response.body)
  end

  private

  def issue_token(user)
    ApiTokenIssuer.new.issue(user: user, attributes: { name: "API", expires_in_days: "" }).raw_token
  end

  def json_headers(raw_token)
    {
      "Accept" => "application/json",
      "Authorization" => "Bearer #{raw_token}"
    }
  end

  def create_recognition(user:, status: :pending, result_json: {})
    recognition = ReceiptRecognition.new(user:, status:, result_json:)
    recognition.image.attach(io: StringIO.new("receipt"), filename: "receipt.png", content_type: "image/png")
    recognition.save!
    recognition
  end
end
