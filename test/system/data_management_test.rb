require "application_system_test_case"

class DataManagementSystemTest < BrowserSystemTestCase
  test "signed-in user can open data management page from navigation" do
    user = create(:user, password: "password123")

    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Log in"
    click_link "Data"

    assert_text "Data management"
    assert_text "Export transactions"
    assert_link "Import transactions"
    assert_link "Clear ledger data"
  end
end
