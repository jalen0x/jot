require "test_helper"

class ExternalAuthenticationsTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get external_authentications_path

    assert_redirected_to new_user_session_path
  end

  test "lists the signed-in user's external authentications" do
    user = create(:user, :github_connected)
    create(:user, :github_connected)
    sign_in user

    get external_authentications_path

    assert_response :success
    assert_select "h1", text: /external authentications/i
    assert_select "li", text: /github/i
    assert_select "form[action='#{external_authentication_path("github")}'] button", text: /disconnect/i
  end

  test "shows an empty state when no external authentication is connected" do
    user = create(:user)
    sign_in user

    get external_authentications_path

    assert_response :success
    assert_match(/No external authentications connected/i, response.body)
  end

  test "unlinks the signed-in user's external authentication with current password" do
    user = create(:user, :github_connected, password: "password123")
    sign_in user

    delete external_authentication_path("github"), params: {
      external_authentication: { current_password: "password123" }
    }

    assert_redirected_to external_authentications_path
    assert_nil user.reload.provider
    assert_nil user.uid
  end

  test "does not unlink with an incorrect password" do
    user = create(:user, :github_connected, password: "password123")
    sign_in user

    delete external_authentication_path("github"), params: {
      external_authentication: { current_password: "wrong-password" }
    }

    assert_response :unprocessable_content
    assert_equal "github", user.reload.provider
    assert_match(/Current password is incorrect/i, response.body)
  end
end
