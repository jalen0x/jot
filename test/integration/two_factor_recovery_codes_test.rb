require "test_helper"

class TwoFactorRecoveryCodesTest < ActionDispatch::IntegrationTest
  SECRET = "JBSWY3DPEHPK3PXP"

  test "requires authentication" do
    post two_factor_recovery_codes_path

    assert_redirected_to new_user_session_path
  end

  test "requires enabled two-factor authentication" do
    sign_in create(:user, password: "password123")

    post two_factor_recovery_codes_path, params: {
      two_factor_recovery_codes: { current_password: "password123" }
    }

    assert_redirected_to two_factor_authentication_path
  end

  test "rejects an incorrect current password" do
    user = create_two_factor_user
    old_ids = user.two_factor_recovery_codes.pluck(:id)
    sign_in user

    post two_factor_recovery_codes_path, params: {
      two_factor_recovery_codes: { current_password: "wrong-password" }
    }

    assert_response :unprocessable_content
    assert_match(/password/i, response.body)
    assert_equal old_ids, user.two_factor_recovery_codes.pluck(:id)
  end

  test "regenerates and displays recovery codes once" do
    user = create_two_factor_user
    old_ids = user.two_factor_recovery_codes.pluck(:id)
    sign_in user

    post two_factor_recovery_codes_path, params: {
      two_factor_recovery_codes: { current_password: "password123" }
    }

    assert_response :created
    raw_codes = response.body.scan(/<code[^>]*>([a-z0-9]{5}-[a-z0-9]{5})<\/code>/).flatten
    assert_equal 10, raw_codes.uniq.size
    assert_empty old_ids & user.two_factor_recovery_codes.pluck(:id)
    raw_codes.each do |raw_code|
      assert user.two_factor_recovery_codes.any? { |recovery_code| recovery_code.matches_code?(raw_code) }
    end

    get two_factor_authentication_path

    assert_response :success
    raw_codes.each do |raw_code|
      refute_match raw_code, response.body
    end
  end

  private

  def create_two_factor_user
    user = create(:user, password: "password123")
    user.create_two_factor_authentication!(otp_secret: SECRET, enabled_at: Time.current)
    TwoFactorRecoveryCodeGenerator.new.generate_for(user: user)
    user
  end
end
