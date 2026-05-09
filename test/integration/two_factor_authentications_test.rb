require "test_helper"

class TwoFactorAuthenticationsTest < ActionDispatch::IntegrationTest
  setup do
    @user = FactoryBot.create(:user, password: "password123")
    sign_in(@user)
  end

  test "show requires sign in" do
    delete destroy_user_session_path

    get two_factor_authentication_path
    assert_redirected_to new_user_session_path
  end

  test "show prepares a setup secret and stores it in the session" do
    get two_factor_authentication_path

    assert_response :success
    assert_match(/[A-Z2-7]{32}/, response.body)
    assert session[:pending_two_factor_secret].present?
  end

  test "create rejects a wrong current password" do
    get two_factor_authentication_path
    secret = session[:pending_two_factor_secret]
    code = ROTP::TOTP.new(secret).now

    post two_factor_authentication_path, params: {
      two_factor_authentication: { current_password: "wrong-password", otp_code: code }
    }

    assert_response :unprocessable_content
    refute @user.reload.two_factor_enabled?
  end

  test "create rejects an invalid otp" do
    get two_factor_authentication_path

    post two_factor_authentication_path, params: {
      two_factor_authentication: { current_password: "password123", otp_code: "000000" }
    }

    assert_response :unprocessable_content
    refute @user.reload.two_factor_enabled?
  end

  test "create enables 2FA and shows recovery codes" do
    get two_factor_authentication_path
    secret = session[:pending_two_factor_secret]
    code = ROTP::TOTP.new(secret).now

    post two_factor_authentication_path, params: {
      two_factor_authentication: { current_password: "password123", otp_code: code }
    }

    assert_response :created
    assert @user.reload.two_factor_enabled?
    assert_equal TwoFactorRecoveryCodeGenerator::CODE_COUNT, @user.two_factor_recovery_codes.count
    assert_nil session[:pending_two_factor_secret]
  end

  test "destroy rejects a wrong current password" do
    enable_two_factor

    delete two_factor_authentication_path, params: {
      two_factor_authentication: { current_password: "wrong-password" }
    }

    assert_response :unprocessable_content
    assert @user.reload.two_factor_enabled?
  end

  test "destroy disables 2FA and wipes recovery codes" do
    enable_two_factor

    delete two_factor_authentication_path, params: {
      two_factor_authentication: { current_password: "password123" }
    }

    assert_redirected_to two_factor_authentication_path
    refute @user.reload.two_factor_enabled?
    assert_equal 0, @user.two_factor_recovery_codes.count
  end

  test "destroy when not enabled redirects without error" do
    delete two_factor_authentication_path, params: {
      two_factor_authentication: { current_password: "password123" }
    }

    assert_redirected_to two_factor_authentication_path
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end

  def enable_two_factor
    @user.create_two_factor_authentication!(otp_secret: TwoFactorAuthentication.generate_secret, enabled_at: Time.current)
    TwoFactorRecoveryCodeGenerator.new.generate_for(user: @user)
  end
end
