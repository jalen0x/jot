require "test_helper"

class ProfileLockTest < ActionDispatch::IntegrationTest
  test "signed in user locks and unlocks the current profile" do
    user = FactoryBot.create(:user, first_name: "Jalen", last_name: "Doe", password: "password123")
    sign_in_with_password(user)

    post "/users/profile_lock"
    assert_redirected_to "/users/profile_lock"

    follow_redirect!
    assert_response :success
    assert_select "header", count: 0
    assert_select "h2", text: user.name

    get root_path
    assert_redirected_to "/users/profile_lock"

    delete "/users/profile_lock", params: { password: "wrong-password" }
    assert_response :unprocessable_content
    assert_select "p", text: I18n.t("users.profile_locks.destroy.invalid_password")

    get root_path
    assert_redirected_to "/users/profile_lock"

    delete "/users/profile_lock", params: { password: "password123" }
    assert_redirected_to root_path

    follow_redirect!
    assert_select "header"
  end

  test "unauthenticated users sign in before opening profile lock" do
    get "/users/profile_lock"

    assert_redirected_to new_user_session_path
  end

  private

  def sign_in_with_password(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
    assert_redirected_to root_path
  end
end
