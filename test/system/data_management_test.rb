require "application_system_test_case"

class DataManagementSystemTest < BrowserSystemTestCase
  test "signed-in user can open data management page from navigation" do
    user = create(:user, password: "password123")
    sign_in_as(user)

    visit dashboard_path
    within("#app-sidebar") do
      click_link "Data Management"
    end

    assert_text "Data management"
    assert_text "Export transactions"
    assert_link "Import transactions"
    assert_link "Clear ledger data"
  end
end
