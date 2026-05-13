require "application_system_test_case"

class NavigationTest < BrowserSystemTestCase
  test "signed-in navigation stays usable on mobile width" do
    resize_window_to_mobile
    user = create(:user, password: "password123")
    sign_in_as(user)

    visit dashboard_path

    assert_no_horizontal_overflow
    click_button "Open menu"
    within("#app-sidebar") do
      click_link "Transaction Details"
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

  def assert_no_horizontal_overflow
    overflow = page.evaluate_script(<<~JS)
      Math.max(document.documentElement.scrollWidth, document.body.scrollWidth) - window.innerWidth
    JS
    assert_operator overflow, :<=, 1
  end
end
