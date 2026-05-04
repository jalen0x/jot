require "test_helper"

class LoginRateLimitsTest < ActionDispatch::IntegrationTest
  setup do
    @previous_store = LoginAttemptLimiter.store
    LoginAttemptLimiter.store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    LoginAttemptLimiter.store = @previous_store
  end

  test "rate limits repeated failed sign-in attempts" do
    user = create(:user, password: "password123")

    5.times do
      post user_session_path, params: { user: { email: user.email, password: "wrong-password" } }
    end
    post user_session_path, params: { user: { email: user.email, password: "wrong-password" } }

    assert_response :too_many_requests
    assert_match(/Too many failed sign-in attempts/i, response.body)
  end

  test "successful sign-in clears previous failed attempts" do
    user = create(:user, password: "password123")

    4.times do
      post user_session_path, params: { user: { email: user.email, password: "wrong-password" } }
    end
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    assert_redirected_to root_path

    delete destroy_user_session_path
    post user_session_path, params: { user: { email: user.email, password: "wrong-password" } }
    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    assert_redirected_to root_path
  end
end
