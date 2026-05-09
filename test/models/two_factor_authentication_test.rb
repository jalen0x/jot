require "test_helper"

class TwoFactorAuthenticationTest < ActiveSupport::TestCase
  setup do
    @user = FactoryBot.create(:user)
    @secret = TwoFactorAuthentication.generate_secret
    @two_factor = @user.create_two_factor_authentication!(otp_secret: @secret, enabled_at: Time.current)
  end

  test "generate_secret returns a 32 character base32 string" do
    secret = TwoFactorAuthentication.generate_secret
    assert_equal 32, secret.length
    assert_match(/\A[A-Z2-7]+\z/, secret)
  end

  test "verify_otp accepts the current TOTP code" do
    code = ROTP::TOTP.new(@secret).now
    assert @two_factor.verify_otp(code)
  end

  test "verify_otp accepts a code with embedded whitespace" do
    code = ROTP::TOTP.new(@secret).now
    spaced = code.chars.each_slice(3).map(&:join).join(" ")
    assert @two_factor.verify_otp(spaced)
  end

  test "verify_otp rejects a wrong code" do
    refute @two_factor.verify_otp("000000")
  end

  test "verify_otp refuses to consume the same code twice" do
    code = ROTP::TOTP.new(@secret).now
    assert @two_factor.verify_otp(code)
    refute @two_factor.verify_otp(code)
  end

  test "verify_otp records the consumed timestep" do
    code = ROTP::TOTP.new(@secret).now
    @two_factor.verify_otp(code)
    assert_not_nil @two_factor.reload.last_otp_at
  end

  test "verify_otp returns false for blank input" do
    refute @two_factor.verify_otp(nil)
    refute @two_factor.verify_otp("")
  end

  test "verify_otp returns false when otp_secret is invalid base32" do
    @two_factor.update!(otp_secret: "not-base32!!!")
    refute @two_factor.verify_otp("123456")
  end

  test "provisioning_uri embeds user email and ISSUER" do
    uri = @two_factor.provisioning_uri

    assert_includes uri, ERB::Util.url_encode(@user.email)
    assert_includes uri, "issuer=#{ERB::Util.url_encode(TwoFactorAuthentication::ISSUER)}"
  end
end
