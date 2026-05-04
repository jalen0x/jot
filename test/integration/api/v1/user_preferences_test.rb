require "test_helper"

class ApiV1UserPreferencesTest < ActionDispatch::IntegrationTest
  test "shows the token owner's user preference" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "EUR")
    UserPreference.create!(user: create(:user), default_currency_code: "JPY")
    raw_token = issue_token(user)

    get api_v1_user_preference_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "user_preference" ], body.keys
    user_preference_json = body.fetch("user_preference")
    assert_equal "EUR", user_preference_json.fetch("default_currency_code")
    refute_includes user_preference_json.keys, "user_id"
  end

  test "updates the token owner's user preference" do
    user = create(:user)
    raw_token = issue_token(user)

    patch api_v1_user_preference_path,
      params: { user_preference: { default_currency_code: "cad" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :success
    assert_equal "CAD", user.reload.user_preference.default_currency_code

    user_preference_json = JSON.parse(response.body).fetch("user_preference")
    assert_equal "CAD", user_preference_json.fetch("default_currency_code")
  end

  test "rejects invalid user preference updates" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    raw_token = issue_token(user)

    patch api_v1_user_preference_path,
      params: { user_preference: { default_currency_code: "USDD" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_equal "USD", user.reload.user_preference.default_currency_code
    assert_match(/Default currency code/i, response.body)
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
end
