require "test_helper"

class ApiV1UserCustomExchangeRatesTest < ActionDispatch::IntegrationTest
  test "lists only the token owner's kept custom exchange rates" do
    user = create(:user)
    other_user = create(:user)
    eur = create_rate(user: user, currency_code: "EUR", rate: "1.25")
    gbp = create_rate(user: user, currency_code: "GBP", rate: "0.8")
    discarded = create_rate(user: user, currency_code: "CAD", rate: "1.4")
    discarded.discard!
    create_rate(user: other_user, currency_code: "JPY", rate: "145")
    raw_token = issue_token(user)

    get api_v1_user_custom_exchange_rates_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "user_custom_exchange_rates" ], body.keys
    rates = body.fetch("user_custom_exchange_rates")
    assert_equal [ eur.to_param, gbp.to_param ], rates.map { |item| item.fetch("id") }
    assert_equal [ "EUR", "GBP" ], rates.map { |item| item.fetch("currency_code") }
    assert_equal [ "1.25", "0.8" ], rates.map { |item| item.fetch("rate") }
    refute_includes rates.first.keys, "user_id"
    refute_includes rates.first.keys, "rate_scaled"
  end

  test "shows one custom exchange rate for the token owner" do
    user = create(:user)
    exchange_rate = create_rate(user: user, currency_code: "EUR", rate: "1.25")
    raw_token = issue_token(user)

    get api_v1_user_custom_exchange_rate_path(exchange_rate), headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "user_custom_exchange_rate" ], body.keys
    rate_json = body.fetch("user_custom_exchange_rate")
    assert_equal exchange_rate.to_param, rate_json.fetch("id")
    assert_equal "EUR", rate_json.fetch("currency_code")
    assert_equal "1.25", rate_json.fetch("rate")
    refute_includes rate_json.keys, "user_id"
    refute_includes rate_json.keys, "rate_scaled"
  end

  test "creates a custom exchange rate for the token owner" do
    user = create(:user)
    raw_token = issue_token(user)

    post api_v1_user_custom_exchange_rates_path,
      params: { user_custom_exchange_rate: { currency_code: "eur", rate: "1.25" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :created
    exchange_rate = user.user_custom_exchange_rates.kept.where(currency_code: "EUR").sole
    assert_equal 125_000_000, exchange_rate.rate_scaled

    rate_json = JSON.parse(response.body).fetch("user_custom_exchange_rate")
    assert_equal exchange_rate.to_param, rate_json.fetch("id")
    assert_equal "EUR", rate_json.fetch("currency_code")
    assert_equal "1.25", rate_json.fetch("rate")
  end

  test "updates a custom exchange rate for the token owner" do
    user = create(:user)
    exchange_rate = create_rate(user: user, currency_code: "EUR", rate: "1.25")
    raw_token = issue_token(user)

    patch api_v1_user_custom_exchange_rate_path(exchange_rate),
      params: { user_custom_exchange_rate: { currency_code: "gbp", rate: "0.8" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :success
    exchange_rate.reload
    assert_equal "GBP", exchange_rate.currency_code
    assert_equal 80_000_000, exchange_rate.rate_scaled

    rate_json = JSON.parse(response.body).fetch("user_custom_exchange_rate")
    assert_equal "GBP", rate_json.fetch("currency_code")
    assert_equal "0.8", rate_json.fetch("rate")
  end

  test "rejects the token owner's default currency" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    raw_token = issue_token(user)

    post api_v1_user_custom_exchange_rates_path,
      params: { user_custom_exchange_rate: { currency_code: "usd", rate: "1.25" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_empty user.user_custom_exchange_rates.kept
    assert_match(/default currency/i, response.body)
  end

  test "does not show another user's custom exchange rate" do
    user = create(:user)
    exchange_rate = create_rate(user: create(:user), currency_code: "EUR", rate: "1.25")
    raw_token = issue_token(user)

    get api_v1_user_custom_exchange_rate_path(exchange_rate), headers: json_headers(raw_token)

    assert_response :not_found
  end

  test "does not update another user's custom exchange rate" do
    user = create(:user)
    exchange_rate = create_rate(user: create(:user), currency_code: "EUR", rate: "1.25")
    raw_token = issue_token(user)

    patch api_v1_user_custom_exchange_rate_path(exchange_rate),
      params: { user_custom_exchange_rate: { currency_code: "gbp", rate: "0.8" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_equal "EUR", exchange_rate.reload.currency_code
    assert_equal 125_000_000, exchange_rate.rate_scaled
  end

  test "deletes a custom exchange rate for the token owner" do
    user = create(:user)
    exchange_rate = create_rate(user: user, currency_code: "EUR", rate: "1.25")
    raw_token = issue_token(user)

    delete api_v1_user_custom_exchange_rate_path(exchange_rate), headers: json_headers(raw_token)

    assert_response :no_content
    assert_empty response.body
    assert_predicate exchange_rate.reload, :discarded?
  end

  test "does not delete another user's custom exchange rate" do
    user = create(:user)
    exchange_rate = create_rate(user: create(:user), currency_code: "EUR", rate: "1.25")
    raw_token = issue_token(user)

    delete api_v1_user_custom_exchange_rate_path(exchange_rate), headers: json_headers(raw_token)

    assert_response :not_found
    assert_predicate exchange_rate.reload, :kept?
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

  def create_rate(user:, currency_code:, rate:)
    UserCustomExchangeRate.create!(user: user, currency_code: currency_code, rate: rate)
  end
end
