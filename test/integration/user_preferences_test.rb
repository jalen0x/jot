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
end
