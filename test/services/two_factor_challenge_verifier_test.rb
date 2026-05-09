require "test_helper"

class TwoFactorChallengeVerifierTest < ActiveSupport::TestCase
  setup do
    @user = FactoryBot.create(:user)
    @secret = TwoFactorAuthentication.generate_secret
    @user.create_two_factor_authentication!(otp_secret: @secret, enabled_at: Time.current)
    @recovery_codes = TwoFactorRecoveryCodeGenerator.new.generate_for(user: @user)
  end

  test "verifies a valid TOTP code" do
    result = TwoFactorChallengeVerifier.new.verify(user: @user, code: ROTP::TOTP.new(@secret).now)

    assert_predicate result, :verified?
    refute_predicate result, :used_recovery_code?
  end

  test "verifies and consumes a recovery code" do
    raw = @recovery_codes.first

    result = TwoFactorChallengeVerifier.new.verify(user: @user, code: raw)

    assert_predicate result, :verified?
    assert_predicate result, :used_recovery_code?
    consumed = @user.two_factor_recovery_codes.reload.find { |rc| rc.authenticate_code(raw) }
    assert_predicate consumed, :used?
  end

  test "rejects a wrong code" do
    result = TwoFactorChallengeVerifier.new.verify(user: @user, code: "000000")

    refute_predicate result, :verified?
  end

  test "rejects blank input without touching recovery codes" do
    result = TwoFactorChallengeVerifier.new.verify(user: @user, code: "")

    refute_predicate result, :verified?
    assert_equal TwoFactorRecoveryCodeGenerator::CODE_COUNT, @user.two_factor_recovery_codes.unused.count
  end

  test "an already-used recovery code does not verify a second time" do
    raw = @recovery_codes.first
    TwoFactorChallengeVerifier.new.verify(user: @user, code: raw)

    result = TwoFactorChallengeVerifier.new.verify(user: @user, code: raw)

    refute_predicate result, :verified?
  end
end
