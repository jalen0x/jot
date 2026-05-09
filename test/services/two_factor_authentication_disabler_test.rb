require "test_helper"

class TwoFactorAuthenticationDisablerTest < ActiveSupport::TestCase
  setup do
    @user = FactoryBot.create(:user, password: "password123")
    @user.create_two_factor_authentication!(otp_secret: TwoFactorAuthentication.generate_secret, enabled_at: Time.current)
    TwoFactorRecoveryCodeGenerator.new.generate_for(user: @user)
  end

  test "disables 2FA and wipes recovery codes when password matches" do
    result = TwoFactorAuthenticationDisabler.new.disable(user: @user, current_password: "password123")

    assert_predicate result, :disabled?
    refute @user.reload.two_factor_enabled?
    assert_equal 0, @user.two_factor_recovery_codes.count
  end

  test "leaves state untouched and returns :invalid_password when password is wrong" do
    result = TwoFactorAuthenticationDisabler.new.disable(user: @user, current_password: "wrong")

    refute_predicate result, :disabled?
    assert_equal :invalid_password, result.error
    assert @user.reload.two_factor_enabled?
    assert_equal TwoFactorRecoveryCodeGenerator::CODE_COUNT, @user.two_factor_recovery_codes.count
  end
end
