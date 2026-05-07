require "application_system_test_case"

class TwoFactorAuthenticationSystemTest < BrowserSystemTestCase
  test "signed in user enables two factor authentication in the browser" do
    user = FactoryBot.create(:user, password: "password123")
    sign_in_with_password(user)

    visit edit_user_registration_path
    click_link I18n.t("devise.registrations.edit.two_factor.enable")

    setup_secret = find("code").text
    fill_authenticator_code(ROTP::TOTP.new(setup_secret).now)
    find("form[action='#{user_two_factor_path}'] button[type='submit']").click

    assert_text I18n.t("users.two_factor.backup_codes.title")
    assert_selector "code", minimum: 1
  end

  test "invalid second factor code displays an error in the browser" do
    user = create_two_factor_user

    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "password123"
    find("form[action='#{user_session_path}'] button[type='submit']").click

    fill_authenticator_code("000000")
    find("form[action='#{user_session_path}'] button[type='submit']").click

    assert_text I18n.t("users.sessions.create.invalid_second_factor_code")
    assert_no_selector "header"
  end

  test "authenticator code signs in automatically after six digits" do
    user = create_two_factor_user

    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "password123"
    find("form[action='#{user_session_path}'] button[type='submit']").click

    fill_authenticator_code(user.current_otp)

    assert_selector "header"
  end

  test "authenticator code field uses real Flowbite inputs with native focus" do
    user = create_two_factor_user

    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "password123"
    find("form[action='#{user_session_path}'] button[type='submit']").click

    assert_selector "input#code-1"
    assert_selector "input#code-6"
    assert_no_selector ".second-factor-code-input"
    assert_equal "code-1", page.evaluate_script("document.activeElement.id")

    fill_in "code-1", with: "1"

    assert_equal "1", find("#code-1").value
    assert_equal "code-2", page.evaluate_script("document.activeElement.id")
  end

  test "backup code signs in from the browser" do
    user = create_two_factor_user
    backup_code = user.generate_otp_backup_codes!.first
    user.save!

    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "password123"
    find("form[action='#{user_session_path}'] button[type='submit']").click

    paste_second_factor_code(backup_code)
    find("form[action='#{user_session_path}'] button[type='submit']").click

    assert_selector "header"
  end

  private

  def create_two_factor_user
    FactoryBot.create(:user, password: "password123").tap do |user|
      user.otp_secret = User.generate_otp_secret
      user.otp_required_for_login = true
      user.save!
    end
  end

  def sign_in_with_password(user)
    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "password123"
    find("form[action='#{user_session_path}'] button[type='submit']").click
    assert_selector "header"
  end

  def fill_authenticator_code(code)
    find("#code-1").click
    code.chars.each do |digit|
      page.driver.browser.switch_to.active_element.send_keys(digit)
    end
  end

  def paste_second_factor_code(code)
    find("#code-1")
    page.execute_script(<<~JS, code)
      const event = new Event("paste", {
        bubbles: true,
        cancelable: true
      })
      Object.defineProperty(event, "clipboardData", {
        value: {
          getData: () => arguments[0]
        }
      })
      document.querySelector("#code-1").dispatchEvent(event)
    JS
  end
end
