require "application_system_test_case"

class TwoFactorAuthenticationSystemTest < BrowserSystemTestCase
  include Warden::Test::Helpers

  setup { Warden.test_mode! }
  teardown { Warden.test_reset! }

  test "user enables 2FA in the browser and lands on the recovery codes panel" do
    user = FactoryBot.create(:user, password: "password123")
    login_as(user, scope: :user)

    visit two_factor_authentication_path

    setup_secret = find_field("totp_setup_secret", disabled: true).value
    code = ROTP::TOTP.new(setup_secret).now
    code.chars.each_with_index { |digit, index| fill_in "code_#{index + 1}", with: digit }

    fill_in "two_factor_authentication_current_password", with: "password123"
    find("input[type='submit'][value='#{I18n.t("two_factor_authentications.show.enable")}']").click

    assert_text I18n.t("two_factor_authentications.recovery_code_panel.title")
    assert_selector "code", minimum: TwoFactorRecoveryCodeGenerator::CODE_COUNT
  end
end
