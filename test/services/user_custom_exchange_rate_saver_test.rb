require "test_helper"

class UserCustomExchangeRateSaverTest < ActiveSupport::TestCase
  test "creates a custom exchange rate for the user" do
    user = create(:user)

    result = UserCustomExchangeRateSaver.new.save_rate(
      user: user,
      attributes: { currency_code: "eur", rate: "1.25" }
    )

    assert_predicate result, :saved?
    assert_equal "EUR", result.exchange_rate.currency_code
    assert_equal 125_000_000, result.exchange_rate.rate_scaled
  end

  test "updates the user's active rate instead of duplicating it" do
    user = create(:user)
    existing = UserCustomExchangeRate.create!(user: user, currency_code: "EUR", rate: "1.25")

    result = UserCustomExchangeRateSaver.new.save_rate(
      user: user,
      attributes: { currency_code: "eur", rate: "1.5" }
    )

    assert_predicate result, :saved?
    assert_equal existing.id, result.exchange_rate.id
    assert_equal 1, user.user_custom_exchange_rates.kept.where(currency_code: "EUR").count
    assert_equal 150_000_000, existing.reload.rate_scaled
  end

  test "does not update another user's matching currency" do
    user = create(:user)
    other_user = create(:user)
    other_rate = UserCustomExchangeRate.create!(user: other_user, currency_code: "EUR", rate: "1.25")

    result = UserCustomExchangeRateSaver.new.save_rate(
      user: user,
      attributes: { currency_code: "eur", rate: "1.5" }
    )

    assert_predicate result, :saved?
    assert_equal 150_000_000, result.exchange_rate.rate_scaled
    assert_equal 125_000_000, other_rate.reload.rate_scaled
  end
end
