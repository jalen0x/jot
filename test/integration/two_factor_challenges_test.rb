require "test_helper"

class TwoFactorChallengesTest < ActionDispatch::IntegrationTest
  setup do
    @user = FactoryBot.create(:user, password: "password123")
    @secret = TwoFactorAuthentication.generate_secret
    @recovery_codes = TwoFactorAuthenticationEnabler.new.enable(user: @user, otp_secret: @secret)
  end

  test "sign in with password redirects 2FA users to the challenge" do
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }

    assert_redirected_to new_two_factor_challenge_path
    assert_equal @user.id, session[:pending_two_factor_user_id]
  end

  test "challenge new without a pending sign in redirects to sign in" do
    get new_two_factor_challenge_path

    assert_redirected_to new_user_session_path
  end

  test "challenge new renders when a pending sign in exists" do
    start_pending_sign_in
    get new_two_factor_challenge_path

    assert_response :success
  end

  test "valid otp completes sign in" do
    start_pending_sign_in

    post two_factor_challenge_path, params: {
      two_factor_challenge: { otp_code: ROTP::TOTP.new(@secret).now }
    }

    assert_redirected_to root_path
    assert_nil session[:pending_two_factor_user_id]
  end

  test "valid recovery code consumes it and signs in" do
    start_pending_sign_in
    raw = @recovery_codes.first

    post two_factor_challenge_path, params: { two_factor_challenge: { otp_code: raw } }

    assert_redirected_to root_path
    consumed = @user.two_factor_recovery_codes.reload.find { |rc| rc.authenticate_code(raw) }
    assert_predicate consumed, :used?
  end

  test "recovery code is single-use" do
    start_pending_sign_in
    raw = @recovery_codes.first
    post two_factor_challenge_path, params: { two_factor_challenge: { otp_code: raw } }

    delete destroy_user_session_path
    start_pending_sign_in
    post two_factor_challenge_path, params: { two_factor_challenge: { otp_code: raw } }

    assert_response :unprocessable_content
    assert_equal @user.id, session[:pending_two_factor_user_id]
  end

  test "invalid code re-renders the challenge with 422" do
    start_pending_sign_in

    post two_factor_challenge_path, params: { two_factor_challenge: { otp_code: "000000" } }

    assert_response :unprocessable_content
    assert_equal @user.id, session[:pending_two_factor_user_id]
  end

  private

  def start_pending_sign_in
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end
end
