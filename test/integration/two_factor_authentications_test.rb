require "test_helper"
require "rotp"

class TwoFactorAuthenticationsTest < ActionDispatch::IntegrationTest
  SECRET = "JBSWY3DPEHPK3PXP"

  test "requires authentication" do
    get two_factor_authentication_path

    assert_redirected_to new_user_session_path
  end

  test "shows setup for a user without two-factor authentication" do
    sign_in create(:user)

    with_stubbed_secret(SECRET) do
      get two_factor_authentication_path
    end

    assert_response :success
    assert_match(/two-factor authentication/i, response.body)
    assert_match SECRET, response.body
    assert_match(/enable/i, response.body)
  end

  test "enables two-factor authentication with current password and valid code" do
    user = create(:user, password: "password123")
    sign_in user

    with_stubbed_secret(SECRET) do
      get two_factor_authentication_path
      post two_factor_authentication_path, params: {
        two_factor_authentication: {
          current_password: "password123",
          otp_code: current_code
        }
      }
    end

    assert_redirected_to two_factor_authentication_path
    assert_predicate user.reload, :two_factor_enabled?
  end

  test "rejects setup with an invalid code" do
    user = create(:user, password: "password123")
    sign_in user

    with_stubbed_secret(SECRET) do
      get two_factor_authentication_path
      post two_factor_authentication_path, params: {
        two_factor_authentication: {
          current_password: "password123",
          otp_code: "000000"
        }
      }
    end

    assert_response :unprocessable_content
    assert_match(/invalid/i, response.body)
    refute_predicate user.reload, :two_factor_enabled?
  end

  test "disables two-factor authentication with current password" do
    user = create(:user, password: "password123")
    user.create_two_factor_authentication!(otp_secret: SECRET, enabled_at: Time.current)
    sign_in user

    delete two_factor_authentication_path, params: {
      two_factor_authentication: { current_password: "wrong-password" }
    }

    assert_response :unprocessable_content
    assert_predicate user.reload, :two_factor_enabled?

    delete two_factor_authentication_path, params: {
      two_factor_authentication: { current_password: "password123" }
    }

    assert_redirected_to two_factor_authentication_path
    refute_predicate user.reload, :two_factor_enabled?
  end

  private

  def current_code
    ROTP::TOTP.new(SECRET).now
  end

  def with_stubbed_secret(secret)
    original = TwoFactorAuthentication.method(:generate_secret)
    TwoFactorAuthentication.define_singleton_method(:generate_secret) { secret }
    yield
  ensure
    TwoFactorAuthentication.define_singleton_method(:generate_secret, original)
  end
end
