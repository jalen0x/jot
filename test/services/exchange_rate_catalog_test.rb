require "test_helper"

class ExchangeRateCatalogTest < ActiveSupport::TestCase
  test "builds current user's base currency and kept custom exchange rates" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    create_rate(user: user, currency_code: "EUR", rate: "1.25")
    create_rate(user: user, currency_code: "GBP", rate: "0.8")
    discarded_rate = create_rate(user: user, currency_code: "CAD", rate: "1.4")
    discarded_rate.discard!
    create_rate(user: create(:user), currency_code: "JPY", rate: "145")

    catalog = ExchangeRateCatalog.new.latest_rates(user: user)

    assert_equal "USD", catalog.base_currency_code
    assert_equal [
      { currency_code: "EUR", rate: "1.25" },
      { currency_code: "GBP", rate: "0.8" },
      { currency_code: "USD", rate: "1" }
    ], catalog.exchange_rates.map { |rate| { currency_code: rate.currency_code, rate: rate.rate } }
  end

  test "falls back to USD when the user has no preference" do
    user = create(:user)

    catalog = ExchangeRateCatalog.new.latest_rates(user: user)

    assert_equal "USD", catalog.base_currency_code
    assert_equal [ { currency_code: "USD", rate: "1" } ], catalog.exchange_rates.map { |rate| { currency_code: rate.currency_code, rate: rate.rate } }
  end

  test "includes latest provider snapshots for the user's base currency" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    create_snapshot(base_currency_code: "USD", currency_code: "EUR", rate: "1.1", observed_at: 2.days.ago)
    create_snapshot(base_currency_code: "USD", currency_code: "EUR", rate: "1.2", observed_at: 1.day.ago)
    create_snapshot(base_currency_code: "USD", currency_code: "GBP", rate: "0.8", observed_at: 1.day.ago)
    create_snapshot(base_currency_code: "CAD", currency_code: "JPY", rate: "145", observed_at: 1.day.ago)

    catalog = ExchangeRateCatalog.new.latest_rates(user: user)

    assert_equal [
      { currency_code: "EUR", rate: "1.2" },
      { currency_code: "GBP", rate: "0.8" },
      { currency_code: "USD", rate: "1" }
    ], catalog.exchange_rates.map { |rate| { currency_code: rate.currency_code, rate: rate.rate } }
  end

  test "custom exchange rates override provider snapshots" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    create_snapshot(base_currency_code: "USD", currency_code: "EUR", rate: "1.2", observed_at: 1.day.ago)
    create_rate(user: user, currency_code: "EUR", rate: "1.25")

    catalog = ExchangeRateCatalog.new.latest_rates(user: user)

    assert_equal [
      { currency_code: "EUR", rate: "1.25" },
      { currency_code: "USD", rate: "1" }
    ], catalog.exchange_rates.map { |rate| { currency_code: rate.currency_code, rate: rate.rate } }
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
