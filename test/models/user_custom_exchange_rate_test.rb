require "test_helper"

class UserCustomExchangeRateTest < ActiveSupport::TestCase
  test "normalizes currency and stores a decimal rate as a scaled integer" do
    exchange_rate = UserCustomExchangeRate.new(user: create(:user), currency_code: " eur ", rate: "7.123456789")

    assert_predicate exchange_rate, :valid?, exchange_rate.errors.full_messages.to_sentence
    assert_equal "EUR", exchange_rate.currency_code
    assert_equal 712_345_679, exchange_rate.rate_scaled
    assert_equal BigDecimal("7.12345679"), exchange_rate.rate
  end

  test "rejects invalid rates" do
    exchange_rate = UserCustomExchangeRate.new(user: create(:user), currency_code: "EUR", rate: "not-a-number")

    refute_predicate exchange_rate, :valid?
    assert_includes exchange_rate.errors[:rate], "is invalid"
  end

  test "rejects non-positive rates" do
    exchange_rate = UserCustomExchangeRate.new(user: create(:user), currency_code: "EUR", rate: "0")

    refute_predicate exchange_rate, :valid?
    assert_includes exchange_rate.errors[:rate_scaled], "must be greater than 0"
  end

  test "rejects the user's default currency" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    exchange_rate = UserCustomExchangeRate.new(user: user, currency_code: "usd", rate: "1.2")

    refute_predicate exchange_rate, :valid?
    assert_includes exchange_rate.errors[:currency_code], "must differ from default currency"
  end
end
