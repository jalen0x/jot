require "application_system_test_case"

class NavigationTest < BrowserSystemTestCase
  test "signed-in navigation stays usable on mobile width" do
    resize_window_to_mobile
    user = create(:user, password: "password123")

    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    assert_no_horizontal_overflow
    find("summary", text: "Menu").click
    within("details") do
      click_link "Transactions"
    end

    assert_text "Transactions"
    assert_no_horizontal_overflow
  ensure
    resize_window_to_desktop
  end

  private

  def resize_window_to_mobile
    page.driver.browser.manage.window.resize_to(390, 900)
  end

  def resize_window_to_desktop
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  def assert_no_horizontal_overflow
    overflow = page.evaluate_script(<<~JS)
      Math.max(document.documentElement.scrollWidth, document.body.scrollWidth) - window.innerWidth
    JS
    assert_operator overflow, :<=, 1
  end
end
