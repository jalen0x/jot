require "test_helper"

class ApiV1ExchangeRateCatalogsTest < ActionDispatch::IntegrationTest
  test "shows the token owner's exchange rate catalog" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    create_rate(user: user, currency_code: "EUR", rate: "1.25")
    create_snapshot(base_currency_code: "USD", currency_code: "GBP", rate: "0.8", observed_at: 1.day.ago)
    create_snapshot(base_currency_code: "CAD", currency_code: "AUD", rate: "1.1", observed_at: 1.day.ago)
    discarded_rate = create_rate(user: user, currency_code: "CAD", rate: "1.4")
    discarded_rate.discard!
    create_rate(user: create(:user), currency_code: "JPY", rate: "145")
    raw_token = issue_token(user)

    get api_v1_exchange_rate_catalog_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "exchange_rate_catalog" ], body.keys

    catalog = body.fetch("exchange_rate_catalog")
    assert_equal "USD", catalog.fetch("base_currency_code")

    exchange_rates = catalog.fetch("exchange_rates")
    assert_equal [ "EUR", "GBP", "USD" ], exchange_rates.map { |rate| rate.fetch("currency_code") }
    assert_equal [ "1.25", "0.8", "1" ], exchange_rates.map { |rate| rate.fetch("rate") }
    exchange_rates.each do |rate|
      refute_includes rate.keys, "user_id"
      refute_includes rate.keys, "rate_scaled"
    end
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


  def create_snapshot(base_currency_code:, currency_code:, rate:, observed_at:)
    ExchangeRateSnapshot.create!(
      data_source: "manual",
      base_currency_code: base_currency_code,
      currency_code: currency_code,
      rate: rate,
      observed_at: observed_at
    )
  end
end
