require "test_helper"

class Users::GithubAuthenticatorTest < ActiveSupport::TestCase
  test "authenticates an existing github user" do
    user = FactoryBot.create(:user, :github_connected)
    result = Users::GithubAuthenticator.new(auth: github_auth(uid: user.uid, email: user.email)).authenticate

    assert result.authenticated?
    assert_equal user, result.user
    assert_nil result.failure_reason
  end

  test "links an existing email user" do
    user = FactoryBot.create(:user)
    result = Users::GithubAuthenticator.new(auth: github_auth(email: user.email, uid: "new-github-uid")).authenticate

    assert result.authenticated?
    assert_equal user, result.user
    assert_equal "github", user.reload.provider
    assert_equal "new-github-uid", user.uid
  end

  test "creates a new user when email is not yet registered" do
    assert_difference("User.count", 1) do
      result = Users::GithubAuthenticator.new(auth: github_auth(email: "new@example.com", uid: "fresh-uid", name: "New Person")).authenticate

      assert result.authenticated?
      assert_equal "new@example.com", result.user.email
      assert_equal "github", result.user.provider
      assert_equal "fresh-uid", result.user.uid
      assert_equal "New", result.user.first_name
      assert_equal "Person", result.user.last_name
    end
  end

  test "fails when github does not provide an email" do
    result = Users::GithubAuthenticator.new(auth: github_auth(email: nil, uid: "missing-email-uid")).authenticate

    refute result.authenticated?
    assert_nil result.user
    assert_equal :missing_email, result.failure_reason
  end

  private

  def github_auth(email:, uid: "github-uid", name: "Git Hub")
    OmniAuth::AuthHash.new(
      provider: "github",
      uid: uid,
      info: {
        email: email,
        name: name
      }
    )
  end
end
