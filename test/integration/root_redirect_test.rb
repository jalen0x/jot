require "test_helper"

class RootRedirectTest < ActionDispatch::IntegrationTest
  test "root sends guests to sign in instead of rendering the template landing page" do
    get root_path

    assert_redirected_to new_user_session_path
  end

  test "root sends signed in users to account settings" do
    user = FactoryBot.create(:user, password: "password123")

    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
    follow_redirect!

    assert_redirected_to edit_user_registration_path
  end
end
