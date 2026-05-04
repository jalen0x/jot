require "test_helper"

class ReceiptRecognitionsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "requires authentication" do
    get new_receipt_recognition_path

    assert_redirected_to new_user_session_path
  end

  test "creates a pending receipt recognition and enqueues processing" do
    user = create(:user)
    sign_in user

    assert_enqueued_with(job: ReceiptRecognitionJob) do
      post receipt_recognitions_path, params: {
        receipt_recognition: { image: fixture_file_upload("avatar.png", "image/png") }
      }
    end

    recognition = user.receipt_recognitions.sole
    assert_redirected_to receipt_recognition_path(recognition)
    assert_predicate recognition, :pending?
    assert_predicate recognition.image, :attached?
  end

  test "show subscribes to recognition updates" do
    user = create(:user)
    recognition = create_recognition(user:)
    sign_in user

    get receipt_recognition_path(recognition)

    assert_response :success
    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']"
  end

  test "shows only the signed-in user's receipt recognition" do
    user = create(:user)
    other_user = create(:user)
    recognition = create_recognition(user: other_user)
    sign_in user

    get receipt_recognition_path(recognition)

    assert_response :not_found
  end

  private

  def create_recognition(user:)
    recognition = ReceiptRecognition.new(user:, status: :pending)
    recognition.image.attach(io: StringIO.new("receipt"), filename: "receipt.png", content_type: "image/png")
    recognition.save!
    recognition
  end
end
