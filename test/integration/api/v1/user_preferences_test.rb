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
    assert_equal "en", user_preference_json["locale"]
    assert_equal "year_month_day", user_preference_json["date_format"]
    refute_includes user_preference_json.keys, "user_id"
  end

  test "updates the token owner's user preference" do
    user = create(:user)
    account = create_account(user: user, name: "Savings")
    raw_token = issue_token(user)

    patch api_v1_user_preference_path,
      params: { user_preference: { default_currency_code: "cad", locale: "zh-CN", date_format: "day_month_year", default_account_id: account.to_param } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :success
    assert_equal "CAD", user.reload.user_preference.default_currency_code

    user_preference_json = JSON.parse(response.body).fetch("user_preference")
    assert_equal "CAD", user_preference_json.fetch("default_currency_code")
    assert_equal "zh-CN", user_preference_json["locale"]
    assert_equal "day_month_year", user_preference_json["date_format"]
    assert_equal account.to_param, user_preference_json["default_account_id"]
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

  test "rejects unsupported locale updates" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    raw_token = issue_token(user)

    patch api_v1_user_preference_path,
      params: { user_preference: { default_currency_code: "usd", locale: "fr" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_match(/Locale/i, response.body)
  end

  test "rejects unsupported date format updates" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    raw_token = issue_token(user)

    patch api_v1_user_preference_path,
      params: { user_preference: { default_currency_code: "usd", locale: "en", date_format: "iso_week" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_match(/Date format/i, response.body)
  end

  test "rejects another user's default account" do
    user = create(:user)
    other_account = create_account(user: create(:user), name: "Other Savings")
    raw_token = issue_token(user)

    patch api_v1_user_preference_path,
      params: { user_preference: { default_currency_code: "usd", locale: "en", date_format: "year_month_day", default_account_id: other_account.to_param } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_match(/Default account/i, response.body)
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

  def create_account(user:, name:)
    Account.create!(
      user: user,
      name: name,
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: 0,
      display_order: 1
    )
  end
end
