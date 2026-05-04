require "test_helper"
require "webmock/minitest"

class ExchangeRateRefreshJobTest < ActiveJob::TestCase
  BANK_OF_CANADA_URL = "https://www.bankofcanada.ca/valet/observations/group/FX_RATES_DAILY/json?recent=1"

  test "refreshes provider snapshots through the job" do
    stub_request(:get, BANK_OF_CANADA_URL).to_return(
      status: 200,
      headers: { "Content-Type" => "application/json" },
      body: {
        observations: [
          {
            d: "2026-05-01",
            FXUSDCAD: { v: "1.25" }
          }
        ]
      }.to_json
    )

    ExchangeRateRefreshJob.perform_now("bank_of_canada")

    snapshot = ExchangeRateSnapshot.find_by!(data_source: "Bank of Canada", base_currency_code: "CAD", currency_code: "USD")
    assert_equal "0.8", snapshot.rate.to_s("F")
  end
end
