require "test_helper"

class UserCustomExchangeRatesTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get user_custom_exchange_rates_path

    assert_redirected_to new_user_session_path
  end

  test "lists only the signed-in user's active exchange rates" do
    user = create(:user)
    other_user = create(:user)
    create_rate(user: user, currency_code: "EUR", rate: "1.25")
    discarded = create_rate(user: user, currency_code: "GBP", rate: "0.8")
    discarded.discard!
    create_rate(user: other_user, currency_code: "JPY", rate: "145")
    sign_in user

    get user_custom_exchange_rates_path

    assert_response :success
    assert_match "EUR", response.body
    refute_match "GBP", response.body
    refute_match "JPY", response.body
  end

  test "creates and updates a custom exchange rate from string params" do
    user = create(:user)
    sign_in user

    post user_custom_exchange_rates_path, params: {
      user_custom_exchange_rate: {
        currency_code: "eur",
        rate: "1.25"
      }
    }

    assert_redirected_to user_custom_exchange_rates_path
    exchange_rate = user.user_custom_exchange_rates.kept.find_by!(currency_code: "EUR")
    assert_equal 125_000_000, exchange_rate.rate_scaled

    post user_custom_exchange_rates_path, params: {
      user_custom_exchange_rate: {
        currency_code: "eur",
        rate: "1.5"
      }
    }

    assert_redirected_to user_custom_exchange_rates_path
    assert_equal 1, user.user_custom_exchange_rates.kept.where(currency_code: "EUR").count
    assert_equal 150_000_000, exchange_rate.reload.rate_scaled
  end

  test "rejects the user's default currency" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD")
    sign_in user

    post user_custom_exchange_rates_path, params: {
      user_custom_exchange_rate: {
        currency_code: "usd",
        rate: "1.25"
      }
    }

    assert_response :unprocessable_content
    assert_match(/must differ from default currency/i, response.body)
  end

  test "destroys only the signed-in user's exchange rate" do
    user = create(:user)
    other_user = create(:user)
    exchange_rate = create_rate(user: user, currency_code: "EUR", rate: "1.25")
    other_rate = create_rate(user: other_user, currency_code: "JPY", rate: "145")
    sign_in user

    delete user_custom_exchange_rate_path(exchange_rate)

    assert_redirected_to user_custom_exchange_rates_path
    assert_predicate exchange_rate.reload, :discarded?
    assert_predicate other_rate.reload, :kept?
  end

  private

  def create_rate(user:, currency_code:, rate:)
    UserCustomExchangeRate.create!(user: user, currency_code: currency_code, rate: rate)
  end
end
