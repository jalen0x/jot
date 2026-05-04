require "test_helper"

class ApplicationLocksTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get application_lock_path

    assert_redirected_to new_user_session_path
  end

  test "enables application lock with current password and pin confirmation" do
    user = create(:user, password: "password123")
    sign_in user

    post application_lock_path, params: lock_params(current_password: "password123", pin_code: "123456", pin_code_confirmation: "123456")

    assert_redirected_to application_lock_path
    application_lock = user.reload.application_lock
    assert application_lock.matches_pin?("123456")
    refute_equal "123456", application_lock.pin_digest
  end

  test "does not enable application lock with wrong current password" do
    user = create(:user, password: "password123")
    sign_in user

    post application_lock_path, params: lock_params(current_password: "wrong-password", pin_code: "123456", pin_code_confirmation: "123456")

    assert_response :unprocessable_content
    assert_nil user.reload.application_lock
    assert_match(/Current password is incorrect/i, response.body)
  end

  test "locks the current session and requires unlock for protected pages" do
    user = create(:user)
    ApplicationLock.create!(user: user, pin_digest: ApplicationLock.digest("123456"))
    sign_in user

    post lock_application_lock_path

    assert_redirected_to unlock_application_lock_path
    get dashboard_path
    assert_redirected_to unlock_application_lock_path
  end

  test "keeps the session locked for a wrong pin" do
    user = create(:user)
    ApplicationLock.create!(user: user, pin_digest: ApplicationLock.digest("123456"))
    sign_in user

    post unlock_application_lock_path, params: unlock_params(pin_code: "000000")

    assert_response :unprocessable_content
    assert_match(/PIN code is invalid/i, response.body)
    get dashboard_path
    assert_redirected_to unlock_application_lock_path
  end

  test "unlocks the session with the correct pin" do
    user = create(:user)
    ApplicationLock.create!(user: user, pin_digest: ApplicationLock.digest("123456"))
    sign_in user

    post unlock_application_lock_path, params: unlock_params(pin_code: "123456")

    assert_redirected_to dashboard_path
    get dashboard_path
    assert_response :success
  end

  test "disables application lock with current password" do
    user = create(:user, password: "password123")
    ApplicationLock.create!(user: user, pin_digest: ApplicationLock.digest("123456"))
    sign_in user

    delete application_lock_path, params: { application_lock: { current_password: "password123" } }

    assert_response :see_other
    assert_redirected_to application_lock_path
    assert_nil user.reload.application_lock
    follow_redirect!
    assert_match(/Not enabled/i, response.body)
  end

  private

  def lock_params(current_password:, pin_code:, pin_code_confirmation:)
    {
      application_lock: {
        current_password: current_password,
        pin_code: pin_code,
        pin_code_confirmation: pin_code_confirmation
      }
    }
  end

  def unlock_params(pin_code:)
    { application_lock: { pin_code: pin_code } }
  end
end
