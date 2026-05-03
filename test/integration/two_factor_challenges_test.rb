require "test_helper"
require "rotp"

class TwoFactorChallengesTest < ActionDispatch::IntegrationTest
  SECRET = "JBSWY3DPEHPK3PXP"

  test "password sign-in for a two-factor user redirects to challenge without signing in" do
    user = create_two_factor_user

    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    assert_redirected_to new_two_factor_challenge_path

    get dashboard_path

    assert_redirected_to new_user_session_path
  end

  test "valid challenge code completes sign-in" do
    user = create_two_factor_user
    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    post two_factor_challenge_path, params: {
      two_factor_challenge: { otp_code: current_code }
    }

    assert_redirected_to root_path

    get dashboard_path

    assert_response :success
  end

  test "invalid challenge code does not sign in" do
    user = create_two_factor_user
    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    post two_factor_challenge_path, params: {
      two_factor_challenge: { otp_code: "000000" }
    }

    assert_response :unprocessable_content
    assert_match(/invalid/i, response.body)

    get dashboard_path

    assert_redirected_to new_user_session_path
  end

  test "recovery code completes sign-in and marks the code used" do
    user = create_two_factor_user
    raw_code = TwoFactorRecoveryCodeGenerator.new.generate_for(user: user).first
    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    post two_factor_challenge_path, params: {
      two_factor_challenge: { otp_code: raw_code }
    }

    assert_redirected_to root_path
    assert user.two_factor_recovery_codes.reload.find { |recovery_code| recovery_code.matches_code?(raw_code) }.used?

    get dashboard_path

    assert_response :success
  end

  test "used recovery code cannot be reused" do
    user = create_two_factor_user
    raw_code = TwoFactorRecoveryCodeGenerator.new.generate_for(user: user).first
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    post two_factor_challenge_path, params: {
      two_factor_challenge: { otp_code: raw_code }
    }
    delete destroy_user_session_path
    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    post two_factor_challenge_path, params: {
      two_factor_challenge: { otp_code: raw_code }
    }

    assert_response :unprocessable_content
    assert_match(/invalid/i, response.body)
  end

  test "users without two-factor authentication still sign in normally" do
    user = create(:user, password: "password123")

    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    assert_redirected_to root_path

    get dashboard_path

    assert_response :success
  end

  test "challenge page requires a pending two-factor login" do
    get new_two_factor_challenge_path

    assert_redirected_to new_user_session_path
  end

  private

  def create_two_factor_user
    user = create(:user, password: "password123")
    user.create_two_factor_authentication!(otp_secret: SECRET, enabled_at: Time.current)
    user
  end

  def current_code
    ROTP::TOTP.new(SECRET).now
  end
end
