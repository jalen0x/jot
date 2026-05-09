require "test_helper"

class ApplicationLocksTest < ActionDispatch::IntegrationTest
  setup do
    @user = FactoryBot.create(:user, password: "password123")
    sign_in(@user)
  end

  test "show requires sign in" do
    delete destroy_user_session_path

    get application_lock_path
    assert_redirected_to new_user_session_path
  end

  test "show renders the setup form when no lock exists" do
    get application_lock_path

    assert_response :success
  end

  test "create rejects a wrong current password" do
    post application_lock_path, params: {
      application_lock: { current_password: "wrong-password", pin: "123456", pin_confirmation: "123456" }
    }

    assert_response :unprocessable_content
    refute @user.reload.application_lock_enabled?
  end

  test "create rejects mismatched pin confirmation" do
    post application_lock_path, params: {
      application_lock: { current_password: "password123", pin: "123456", pin_confirmation: "654321" }
    }

    assert_response :unprocessable_content
    refute @user.reload.application_lock_enabled?
  end

  test "create rejects a non-numeric or wrong-length pin" do
    [ "abcdef", "12345", "1234567" ].each do |bad|
      post application_lock_path, params: {
        application_lock: { current_password: "password123", pin: bad, pin_confirmation: bad }
      }
      assert_response :unprocessable_content
    end

    refute @user.reload.application_lock_enabled?
  end

  test "create with valid params enables the lock and marks it unlocked" do
    post application_lock_path, params: {
      application_lock: { current_password: "password123", pin: "123456", pin_confirmation: "123456" }
    }

    assert_redirected_to application_lock_path
    assert @user.reload.application_lock_enabled?
    assert_equal @user.id, session[:application_lock_unlocked_user_id]
  end

  test "destroy rejects a wrong current password" do
    @user.create_application_lock!(pin: "123456")

    delete application_lock_path, params: { application_lock: { current_password: "wrong" } }

    assert_response :unprocessable_content
    assert @user.reload.application_lock_enabled?
  end

  test "destroy with valid password disables the lock and clears the unlock session" do
    @user.create_application_lock!(pin: "123456")
    session_state = post(application_lock_session_path, params: { application_lock: { pin: "123456" } })
    assert_equal @user.id, session[:application_lock_unlocked_user_id]

    delete application_lock_path, params: { application_lock: { current_password: "password123" } }

    assert_redirected_to application_lock_path
    refute @user.reload.application_lock_enabled?
    assert_nil session[:application_lock_unlocked_user_id]
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
  end
end
