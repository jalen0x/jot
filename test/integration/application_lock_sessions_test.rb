require "test_helper"

class ApplicationLockSessionsTest < ActionDispatch::IntegrationTest
  setup do
    @user = FactoryBot.create(:user, password: "password123")
    @user.create_application_lock!(pin: "123456")
    sign_in(@user)
  end

  test "new renders the unlock form" do
    get new_application_lock_session_path

    assert_response :success
  end

  test "create with valid pin marks the session unlocked" do
    post application_lock_session_path, params: { application_lock: { pin_code: "123456" } }

    assert_redirected_to dashboard_path
    assert_equal @user.id, session[:application_lock_unlocked_user_id]
  end

  test "create with wrong pin re-renders the unlock form" do
    post application_lock_session_path, params: { application_lock: { pin_code: "000000" } }

    assert_response :unprocessable_content
    assert_nil session[:application_lock_unlocked_user_id]
  end

  test "destroy clears the unlock and redirects back to the unlock screen" do
    post application_lock_session_path, params: { application_lock: { pin_code: "123456" } }
    assert_equal @user.id, session[:application_lock_unlocked_user_id]

    delete application_lock_session_path

    assert_redirected_to new_application_lock_session_path
    assert_nil session[:application_lock_unlocked_user_id]
  end

  test "locked user is redirected away from arbitrary pages until unlocked" do
    get edit_user_registration_path
    assert_redirected_to new_application_lock_session_path

    post application_lock_session_path, params: { application_lock: { pin_code: "123456" } }

    get edit_user_registration_path
    assert_response :success
  end

  test "locked user can still sign out without unlocking" do
    delete destroy_user_session_path

    assert_redirected_to root_path
    follow_redirect!
    assert_redirected_to new_user_session_path
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
