require "test_helper"
require "webmock/minitest"

class ExchangeRateUpdaterTest < ActiveSupport::TestCase
  BANK_OF_CANADA_URL = "https://www.bankofcanada.ca/valet/observations/group/FX_RATES_DAILY/json?recent=1"

  test "refreshes bank of canada snapshots" do
    stub_bank_of_canada_response

    result = ExchangeRateUpdater.new.refresh_rates(provider_key: "bank_of_canada")

    assert_equal 2, result.snapshots.size
    usd = ExchangeRateSnapshot.find_by!(data_source: "Bank of Canada", base_currency_code: "CAD", currency_code: "USD")
    eur = ExchangeRateSnapshot.find_by!(data_source: "Bank of Canada", base_currency_code: "CAD", currency_code: "EUR")
    assert_equal "0.8", usd.rate.to_s("F")
    assert_equal "2.0", eur.rate.to_s("F")
    assert_equal expected_observed_at.to_i, usd.observed_at.to_i
    assert_equal "https://www.bankofcanada.ca/rates/exchange/daily-exchange-rates/", usd.reference_url
  end

  test "refresh is idempotent for the same provider observation" do
    stub_bank_of_canada_response

    ExchangeRateUpdater.new.refresh_rates(provider_key: "bank_of_canada")
    ExchangeRateUpdater.new.refresh_rates(provider_key: "bank_of_canada")

    assert_equal 2, ExchangeRateSnapshot.where(data_source: "Bank of Canada").count
  end

  test "unsupported provider key raises without writing snapshots" do
    assert_raises(ExchangeRateProviders::UnsupportedProviderError) do
      ExchangeRateUpdater.new.refresh_rates(provider_key: "unknown")
    end

    assert_equal 0, ExchangeRateSnapshot.count
  end

  test "failed provider response raises without writing snapshots" do
    stub_request(:get, BANK_OF_CANADA_URL).to_return(status: 503, body: "unavailable")

    assert_raises(ExchangeRateProviders::FetchError) do
      ExchangeRateUpdater.new.refresh_rates(provider_key: "bank_of_canada")
    end

    assert_equal 0, ExchangeRateSnapshot.count
  end

  test "provider network failures raise fetch error without writing snapshots" do
    stub_request(:get, BANK_OF_CANADA_URL).to_timeout

    error = assert_raises(ExchangeRateProviders::FetchError) do
      ExchangeRateUpdater.new.refresh_rates(provider_key: "bank_of_canada")
    end

    assert_match(/request failed/i, error.message)
    assert_equal 0, ExchangeRateSnapshot.count
  end

  private

  def stub_bank_of_canada_response
    stub_request(:get, BANK_OF_CANADA_URL).to_return(
      status: 200,
      headers: { "Content-Type" => "application/json" },
      body: {
        observations: [
          {
            d: "2026-05-01",
            FXUSDCAD: { v: "1.25" },
            FXEURCAD: { v: "0.5" }
          }
        ]
      }.to_json
    )
  end

  def expected_observed_at
    Time.find_zone!("America/Toronto").parse("2026-05-01 16:30")
  end
end
