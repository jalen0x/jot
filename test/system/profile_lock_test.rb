require "application_system_test_case"

class ProfileLockSystemTest < BrowserSystemTestCase
  test "keyboard shortcut locks the current profile" do
    user = FactoryBot.create(:user, first_name: "Jalen", last_name: "Doe", password: "password123")
    sign_in_with_password(user)

    page.execute_script(<<~JS)
      document.dispatchEvent(new KeyboardEvent("keydown", {
        key: "l",
        metaKey: true,
        bubbles: true,
        cancelable: true
      }))
    JS

    assert_current_path user_profile_lock_path, ignore_query: true
    assert_no_selector "header"
    assert_text user.name
  end

  private

  def sign_in_with_password(user)
    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "password123"
    find("form[action='#{user_session_path}'] button[type='submit']").click
    assert_selector "header"
  end
end
