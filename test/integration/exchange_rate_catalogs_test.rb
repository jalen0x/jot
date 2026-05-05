require "test_helper"

class ExchangeRateCatalogsTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get exchange_rate_catalog_path

    assert_redirected_to new_user_session_path
  end

  test "shows the signed-in user's effective exchange rate catalog" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    create_rate(user: user, currency_code: "EUR", rate: "1.25")
    create_snapshot(base_currency_code: "USD", currency_code: "GBP", rate: "0.8", observed_at: 1.day.ago)
    create_snapshot(base_currency_code: "CAD", currency_code: "AUD", rate: "1.1", observed_at: 1.day.ago)
    discarded_rate = create_rate(user: user, currency_code: "CAD", rate: "1.4")
    discarded_rate.discard!
    create_rate(user: create(:user), currency_code: "JPY", rate: "145")
    sign_in user

    get exchange_rate_catalog_path

    assert_response :success
    assert_match(/Base currency/i, response.body)
    assert_match(/USD/, response.body)
    assert_match(/EUR/, response.body)
    assert_match(/1.25/, response.body)
    assert_match(/GBP/, response.body)
    assert_match(/0.8/, response.body)
    refute_match(/AUD/, response.body)
    refute_match(/CAD/, response.body)
    refute_match(/JPY/, response.body)
    assert_select "a[href='#{user_custom_exchange_rates_path}']", text: /Manage custom rates/i
  end

  private

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
