require "test_helper"

class ExchangeRateSnapshotTest < ActiveSupport::TestCase
  test "normalizes currency codes and stores scaled rate" do
    snapshot = ExchangeRateSnapshot.create!(
      data_source: "manual",
      base_currency_code: "usd",
      currency_code: "eur",
      rate: "1.25",
      observed_at: Time.utc(2026, 5, 4, 10, 0, 0),
      reference_url: "https://example.test/rates"
    )

    assert_equal "USD", snapshot.base_currency_code
    assert_equal "EUR", snapshot.currency_code
    assert_equal 125_000_000, snapshot.rate_scaled
    assert_equal "1.25", snapshot.rate.to_s("F")
  end

  test "requires unique provider observation per base and target currency" do
    attributes = {
      data_source: "manual",
      base_currency_code: "USD",
      currency_code: "EUR",
      rate: "1.25",
      observed_at: Time.utc(2026, 5, 4, 10, 0, 0)
    }
    ExchangeRateSnapshot.create!(attributes)

    duplicate = ExchangeRateSnapshot.new(attributes)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:currency_code], "has already been taken", duplicate.errors.full_messages.to_sentence
  end

  test "database rejects non-positive scaled rates" do
    snapshot = ExchangeRateSnapshot.create!(
      data_source: "manual",
      base_currency_code: "USD",
      currency_code: "EUR",
      rate: "1.25",
      observed_at: Time.utc(2026, 5, 4, 10, 0, 0)
    )

    error = assert_raises(ActiveRecord::StatementInvalid) do
      snapshot.update_column(:rate_scaled, 0)
    end
    assert_match(/exchange_rate_snapshots_rate_scaled_positive/i, error.message)
  end
end
