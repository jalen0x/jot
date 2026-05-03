require "test_helper"
require "rotp"
require "uri"

class TwoFactorAuthenticationTest < ActiveSupport::TestCase
  SECRET = "JBSWY3DPEHPK3PXP"

  test "verifies current totp code" do
    two_factor_authentication = build_two_factor_authentication
    code = ROTP::TOTP.new(SECRET).now

    assert two_factor_authentication.verify_otp(code)
  end

  test "rejects an invalid totp code" do
    two_factor_authentication = build_two_factor_authentication

    refute two_factor_authentication.verify_otp("000000")
  end

  test "builds a provisioning uri for the user's email" do
    user = create(:user, email: "alice@example.com")
    two_factor_authentication = user.build_two_factor_authentication(
      otp_secret: SECRET,
      enabled_at: Time.current
    )

    uri = URI.decode_www_form_component(two_factor_authentication.provisioning_uri)

    assert_includes uri, "otpauth://totp/"
    assert_includes uri, "alice@example.com"
    assert_includes uri, "issuer=#{TemplateBase.config.application_name}"
  end

  test "allows one two-factor authentication record per user" do
    user = create(:user)
    user.create_two_factor_authentication!(otp_secret: SECRET, enabled_at: Time.current)

    duplicate = TwoFactorAuthentication.new(user: user, otp_secret: TwoFactorAuthentication.generate_secret, enabled_at: Time.current)

    refute duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  private

  def build_two_factor_authentication
    create(:user).build_two_factor_authentication(
      otp_secret: SECRET,
      enabled_at: Time.current
    )
  end
end
