require "application_system_test_case"

class ApplicationLockSystemTest < BrowserSystemTestCase
  include Warden::Test::Helpers

  setup { Warden.test_mode! }
  teardown { Warden.test_reset! }

  test "locked user is redirected to the unlock screen and unlocks with a PIN" do
    user = FactoryBot.create(:user, password: "password123")
    user.create_application_lock!(pin: "246810")
    login_as(user, scope: :user)

    visit edit_user_registration_path

    assert_current_path new_application_lock_session_path
    assert_text I18n.t("application_lock_sessions.new.title")

    "246810".chars.each_with_index { |digit, index| fill_in "code_#{index + 1}", with: digit }

    # auto_submit fires once all six digits are entered; root_path then redirects
    # the signed-in user to their account settings.
    assert_current_path edit_user_registration_path
  end
end
