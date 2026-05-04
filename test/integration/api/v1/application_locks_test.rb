require "test_helper"

class ApiV1ApplicationLocksTest < ActionDispatch::IntegrationTest
  test "shows disabled status for the token owner" do
    user = create(:user)
    ApplicationLock.create!(user: create(:user), pin_digest: ApplicationLock.digest("123456"))
    raw_token = issue_token(user)

    get api_v1_application_lock_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "application_lock" ], body.keys
    assert_equal({ "enabled" => false }, body.fetch("application_lock"))
  end

  test "shows enabled status without internal digest fields" do
    user = create(:user)
    ApplicationLock.create!(user: user, pin_digest: ApplicationLock.digest("123456"))
    raw_token = issue_token(user)

    get api_v1_application_lock_path, headers: json_headers(raw_token)

    assert_response :success
    application_lock_json = JSON.parse(response.body).fetch("application_lock")
    assert_equal true, application_lock_json.fetch("enabled")
    assert application_lock_json.fetch("created_at").present?
    refute_includes application_lock_json.keys, "pin_digest"
    refute_includes application_lock_json.keys, "user_id"
  end

  test "enables application lock with current password and pin confirmation" do
    user = create(:user, password: "password123")
    raw_token = issue_token(user)

    post api_v1_application_lock_path,
      params: lock_params(current_password: "password123", pin_code: "123456", pin_code_confirmation: "123456"),
      headers: json_headers(raw_token),
      as: :json

    assert_response :created
    application_lock = user.reload.application_lock
    assert application_lock.matches_pin?("123456")
    refute_equal "123456", application_lock.pin_digest
    assert_equal true, JSON.parse(response.body).dig("application_lock", "enabled")
  end

  test "rejects an incorrect password when enabling" do
    user = create(:user, password: "password123")
    raw_token = issue_token(user)

    post api_v1_application_lock_path,
      params: lock_params(current_password: "wrong-password", pin_code: "123456", pin_code_confirmation: "123456"),
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_nil user.reload.application_lock
    assert_match(/Current password is incorrect/i, response.body)
  end

  test "rejects invalid pin when enabling" do
    user = create(:user, password: "password123")
    raw_token = issue_token(user)

    post api_v1_application_lock_path,
      params: lock_params(current_password: "password123", pin_code: "12345", pin_code_confirmation: "12345"),
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_nil user.reload.application_lock
    assert_match(/six digits/i, response.body)
  end

  test "rejects mismatched pin confirmation when enabling" do
    user = create(:user, password: "password123")
    raw_token = issue_token(user)

    post api_v1_application_lock_path,
      params: lock_params(current_password: "password123", pin_code: "123456", pin_code_confirmation: "654321"),
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_nil user.reload.application_lock
    assert_match(/confirmation/i, response.body)
  end

  test "disables application lock with current password" do
    user = create(:user, password: "password123")
    ApplicationLock.create!(user: user, pin_digest: ApplicationLock.digest("123456"))
    raw_token = issue_token(user)

    delete api_v1_application_lock_path,
      params: { application_lock: { current_password: "password123" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :no_content
    assert_empty response.body
    assert_nil user.reload.application_lock
  end

  test "rejects an incorrect password when disabling" do
    user = create(:user, password: "password123")
    application_lock = ApplicationLock.create!(user: user, pin_digest: ApplicationLock.digest("123456"))
    raw_token = issue_token(user)

    delete api_v1_application_lock_path,
      params: { application_lock: { current_password: "wrong-password" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_equal application_lock, user.reload.application_lock
    assert_match(/Current password is incorrect/i, response.body)
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

  def lock_params(current_password:, pin_code:, pin_code_confirmation:)
    {
      application_lock: {
        current_password: current_password,
        pin_code: pin_code,
        pin_code_confirmation: pin_code_confirmation
      }
    }
  end
end
