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
    assert_equal "twenty_four_hour", user_preference_json["time_format"]
    assert_equal "western", user_preference_json["number_format"]
    assert_equal 0, user_preference_json["first_day_of_week"]
    assert_equal 1, user_preference_json["fiscal_year_start_month"]
    assert_equal 1, user_preference_json["fiscal_year_start_day"]
    assert_equal "start_year_end_year", user_preference_json["fiscal_year_format"]
    assert_equal "code_after_amount", user_preference_json["currency_display_format"]
    assert_equal "latitude_longitude_decimal_degrees", user_preference_json["coordinate_display_format"]
    assert_equal "danger", user_preference_json["expense_amount_color"]
    assert_equal "success", user_preference_json["income_amount_color"]
    refute_includes user_preference_json.keys, "user_id"
  end

  test "updates the token owner's user preference" do
    user = create(:user)
    account = create_account(user: user, name: "Savings")
    raw_token = issue_token(user)

    patch api_v1_user_preference_path,
      params: { user_preference: { default_currency_code: "cad", locale: "zh-CN", date_format: "day_month_year", time_format: "twelve_hour", number_format: "decimal_comma", first_day_of_week: 1, fiscal_year_start_month: 4, fiscal_year_start_day: 1, fiscal_year_format: "end_short_year", currency_display_format: "code_before_amount", coordinate_display_format: "longitude_latitude_decimal_degrees", expense_amount_color: "warning", income_amount_color: "neutral", default_account_id: account.to_param } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :success
    assert_equal "CAD", user.reload.user_preference.default_currency_code
    assert_equal "twelve_hour", user.reload.user_preference.time_format
    assert_equal 1, user.reload.user_preference.first_day_of_week
    assert_equal 4, user.reload.user_preference.fiscal_year_start_month
    assert_equal 1, user.reload.user_preference.fiscal_year_start_day
    assert_equal "end_short_year", user.reload.user_preference.fiscal_year_format
    assert_equal "code_before_amount", user.reload.user_preference.currency_display_format
    assert_equal "longitude_latitude_decimal_degrees", user.reload.user_preference.coordinate_display_format
    assert_equal "warning", user.reload.user_preference.expense_amount_color
    assert_equal "neutral", user.reload.user_preference.income_amount_color

    user_preference_json = JSON.parse(response.body).fetch("user_preference")
    assert_equal "CAD", user_preference_json.fetch("default_currency_code")
    assert_equal "zh-CN", user_preference_json["locale"]
    assert_equal "day_month_year", user_preference_json["date_format"]
    assert_equal "twelve_hour", user_preference_json["time_format"]
    assert_equal "decimal_comma", user_preference_json["number_format"]
    assert_equal 1, user_preference_json["first_day_of_week"]
    assert_equal 4, user_preference_json["fiscal_year_start_month"]
    assert_equal 1, user_preference_json["fiscal_year_start_day"]
    assert_equal "end_short_year", user_preference_json["fiscal_year_format"]
    assert_equal "code_before_amount", user_preference_json["currency_display_format"]
    assert_equal "longitude_latitude_decimal_degrees", user_preference_json["coordinate_display_format"]
    assert_equal "warning", user_preference_json["expense_amount_color"]
    assert_equal "neutral", user_preference_json["income_amount_color"]
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

  test "rejects unsupported number format updates" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    raw_token = issue_token(user)

    patch api_v1_user_preference_path,
      params: { user_preference: { default_currency_code: "usd", locale: "en", date_format: "year_month_day", number_format: "thin_space" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_match(/Number format/i, response.body)
  end

  test "rejects unsupported first day of week updates" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    raw_token = issue_token(user)

    patch api_v1_user_preference_path,
      params: { user_preference: { default_currency_code: "usd", first_day_of_week: 7 } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_match(/First day of week/i, response.body)
  end

  test "rejects unsupported fiscal year start updates" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    raw_token = issue_token(user)

    patch api_v1_user_preference_path,
      params: { user_preference: { default_currency_code: "usd", fiscal_year_start_month: 2, fiscal_year_start_day: 29 } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_match(/Fiscal year start/i, response.body)
  end

  test "rejects unsupported fiscal year format updates" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    raw_token = issue_token(user)

    patch api_v1_user_preference_path,
      params: { user_preference: { default_currency_code: "usd", fiscal_year_format: "default" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_match(/Fiscal year format/i, response.body)
  end

  test "rejects unsupported currency display format updates" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    raw_token = issue_token(user)

    patch api_v1_user_preference_path,
      params: { user_preference: { default_currency_code: "usd", currency_display_format: "symbol_before_amount" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_match(/Currency display format/i, response.body)
  end

  test "rejects unsupported time format updates" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    raw_token = issue_token(user)

    patch api_v1_user_preference_path,
      params: { user_preference: { default_currency_code: "usd", time_format: "with_seconds" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_match(/Time format/i, response.body)
  end

  test "rejects unsupported coordinate display format updates" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    raw_token = issue_token(user)

    patch api_v1_user_preference_path,
      params: { user_preference: { default_currency_code: "usd", coordinate_display_format: "map_tile" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_match(/Coordinate display format/i, response.body)
  end

  test "rejects unsupported amount color updates" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    raw_token = issue_token(user)

    patch api_v1_user_preference_path,
      params: { user_preference: { default_currency_code: "usd", expense_amount_color: "blue" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_match(/Expense amount color/i, response.body)
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
