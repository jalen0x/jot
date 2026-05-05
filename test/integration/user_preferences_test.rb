require "test_helper"

class UserPreferencesTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get user_preference_path

    assert_redirected_to new_user_session_path
  end

  test "updates the signed-in user's default currency" do
    user = create(:user)
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "eur"
      }
    }

    assert_redirected_to user_preference_path
    follow_redirect!
    assert_match(/Preferences updated/i, response.body)
    assert_equal "EUR", user.reload.user_preference.default_currency_code
  end

  test "updates the signed-in user's locale and applies it to later web requests" do
    user = create(:user)
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "usd",
        locale: "zh-CN"
      }
    }

    assert_redirected_to user_preference_path
    follow_redirect!
    assert_response :success
    assert_match(/偏好设置/, response.body)
  end

  test "updates the signed-in user's first day of week" do
    user = create(:user)
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "usd",
        first_day_of_week: "1"
      }
    }

    assert_redirected_to user_preference_path
    assert_equal 1, user.reload.user_preference.first_day_of_week
  end

  test "updates the signed-in user's fiscal year start" do
    user = create(:user)
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "usd",
        fiscal_year_start_month: "4",
        fiscal_year_start_day: "1"
      }
    }

    assert_redirected_to user_preference_path
    assert_equal 4, user.reload.user_preference.fiscal_year_start_month
    assert_equal 1, user.reload.user_preference.fiscal_year_start_day
  end

  test "updates the signed-in user's fiscal year format" do
    user = create(:user)
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "usd",
        fiscal_year_format: "end_short_year"
      }
    }

    assert_redirected_to user_preference_path
    assert_equal "end_short_year", user.reload.user_preference.fiscal_year_format
  end

  test "updates the signed-in user's currency display format" do
    user = create(:user)
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "usd",
        currency_display_format: "code_before_amount"
      }
    }

    assert_redirected_to user_preference_path
    assert_equal "code_before_amount", user.reload.user_preference.currency_display_format
  end

  test "updates the signed-in user's time format" do
    user = create(:user)
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "usd",
        time_format: "twelve_hour"
      }
    }

    assert_redirected_to user_preference_path
    assert_equal "twelve_hour", user.reload.user_preference.time_format
  end

  test "updates the signed-in user's coordinate display format" do
    user = create(:user)
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "usd",
        coordinate_display_format: "longitude_latitude_degrees_minutes_seconds"
      }
    }

    assert_redirected_to user_preference_path
    assert_equal "longitude_latitude_degrees_minutes_seconds", user.reload.user_preference.coordinate_display_format
  end

  test "updates the signed-in user's amount colors" do
    user = create(:user)
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "usd",
        expense_amount_color: "warning",
        income_amount_color: "neutral"
      }
    }

    assert_redirected_to user_preference_path
    assert_equal "warning", user.reload.user_preference.expense_amount_color
    assert_equal "neutral", user.reload.user_preference.income_amount_color
  end

  test "renders validation errors for an invalid currency" do
    user = create(:user)
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "EURO"
      }
    }

    assert_response :unprocessable_content
    assert_match(/Default currency code is invalid/i, response.body)
  end

  test "uses saved default currency for new accounts" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "CNY")
    sign_in user

    get new_account_path

    assert_response :success
    assert_match(/value="CNY"/, response.body)
  end

  test "rejects another user's default account" do
    user = create(:user)
    other_account = create_account(user: create(:user), name: "Other Savings")
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "usd",
        default_account_id: other_account.to_param
      }
    }

    assert_response :unprocessable_content
    assert_nil user.reload.user_preference&.default_account
    assert_match(/Default account/i, response.body)
  end

  private

  def create_account(user:, name:)
    Account.create!(
      user: user,
      name: name,
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: 0,
      display_order: 1
    )
  end
end
