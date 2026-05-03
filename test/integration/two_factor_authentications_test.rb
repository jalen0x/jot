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

    assert_response :created
    assert_predicate user.reload, :two_factor_enabled?
    assert_recovery_codes_shown_once_for(user)
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
    assert_empty user.two_factor_recovery_codes
  end

  test "disables two-factor authentication with current password" do
    user = create(:user, password: "password123")
    user.create_two_factor_authentication!(otp_secret: SECRET, enabled_at: Time.current)
    TwoFactorRecoveryCodeGenerator.new.generate_for(user: user)
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

  def assert_recovery_codes_shown_once_for(user)
    raw_codes = response.body.scan(/<code[^>]*>([a-z0-9]{5}-[a-z0-9]{5})<\/code>/).flatten

    assert_equal 10, raw_codes.uniq.size
    assert_equal 10, user.two_factor_recovery_codes.count
    raw_codes.each do |raw_code|
      refute_includes user.two_factor_recovery_codes.map(&:code_digest), raw_code
      assert user.two_factor_recovery_codes.any? { |recovery_code| recovery_code.matches_code?(raw_code) }
    end

    get two_factor_authentication_path

    assert_response :success
    raw_codes.each do |raw_code|
      refute_match raw_code, response.body
    end
  end

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
