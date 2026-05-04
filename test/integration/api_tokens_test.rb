require "test_helper"

class ApiTokensTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get api_tokens_path

    assert_redirected_to new_user_session_path
  end

  test "rejects an incorrect password" do
    user = create(:user, password: "password123")
    sign_in user

    post api_tokens_path, params: {
      api_token: {
        name: "CLI",
        expires_in_days: "",
        current_password: "wrong-password"
      }
    }

    assert_response :unprocessable_content
    assert_match(/password/i, response.body)
    assert_equal 0, user.api_tokens.count
  end

  test "issues and displays the raw token once" do
    user = create(:user, password: "password123")
    sign_in user

    with_stubbed_token("raw-token-123") do
      post api_tokens_path, params: {
        api_token: {
          name: "CLI",
          expires_in_days: "",
          current_password: "password123"
        }
      }
    end

    assert_response :created
    assert_match "raw-token-123", response.body
    api_token = user.api_tokens.first
    assert api_token.matches_token?("raw-token-123")
    refute_equal "raw-token-123", api_token.token_digest

    get api_tokens_path

    assert_response :success
    refute_match "raw-token-123", response.body
  end

  test "lists only current user's active tokens" do
    user = create(:user)
    other_user = create(:user)
    create_token(user: user, name: "Active")
    create_token(user: user, name: "Expired", expires_at: 1.minute.ago)
    revoked = create_token(user: user, name: "Revoked")
    revoked.discard!
    create_token(user: other_user, name: "Other")
    sign_in user

    get api_tokens_path

    assert_response :success
    assert_match "Active", response.body
    refute_match "Expired", response.body
    refute_match "Revoked", response.body
    refute_match "Other", response.body
    assert_select "form[action='#{api_token_path(user.api_tokens.active.sole)}'][data-turbo-confirm]"
  end

  test "revokes only the signed-in user's token" do
    user = create(:user)
    other_user = create(:user)
    api_token = create_token(user: user, name: "CLI")
    other_token = create_token(user: other_user, name: "Other")
    sign_in user

    delete api_token_path(api_token)

    assert_response :see_other
    assert_redirected_to api_tokens_path
    assert_predicate api_token.reload, :discarded?
    assert_predicate other_token.reload, :kept?
  end

  private

  def with_stubbed_token(raw_token)
    original = SecureRandom.method(:urlsafe_base64)
    SecureRandom.define_singleton_method(:urlsafe_base64) { |*| raw_token }
    yield
  ensure
    SecureRandom.define_singleton_method(:urlsafe_base64, original)
  end

  def create_token(user:, name:, expires_at: 1.day.from_now)
    ApiToken.create!(
      user: user,
      name: name,
      token_digest: BCrypt::Password.create("raw-token"),
      expires_at: expires_at
    )
  end
end
