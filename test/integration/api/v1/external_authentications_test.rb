require "test_helper"

class ApiV1ExternalAuthenticationsTest < ActionDispatch::IntegrationTest
  test "lists the token owner's external authentications" do
    user = create(:user, :github_connected)
    create(:user, :github_connected)
    raw_token = issue_token(user)

    get api_v1_external_authentications_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "external_authentications" ], body.keys
    external_authentications = body.fetch("external_authentications")
    assert_equal 1, external_authentications.size
    external_authentication = external_authentications.first
    assert_equal "github", external_authentication.fetch("id")
    assert_equal "github", external_authentication.fetch("provider")
    refute_includes external_authentication.keys, "uid"
    refute_includes external_authentication.keys, "user_id"
  end

  test "lists an empty collection when only another user is linked" do
    user = create(:user)
    create(:user, :github_connected)
    raw_token = issue_token(user)

    get api_v1_external_authentications_path, headers: json_headers(raw_token)

    assert_response :success
    assert_empty JSON.parse(response.body).fetch("external_authentications")
  end

  test "unlinks the token owner's external authentication with current password" do
    user = create(:user, :github_connected, password: "password123")
    raw_token = issue_token(user)

    delete api_v1_external_authentication_path("github"),
      params: { external_authentication: { current_password: "password123" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :no_content
    assert_empty response.body
    assert_nil user.reload.provider
    assert_nil user.uid
  end

  test "rejects unlink with an incorrect password" do
    user = create(:user, :github_connected, password: "password123")
    raw_token = issue_token(user)

    delete api_v1_external_authentication_path("github"),
      params: { external_authentication: { current_password: "wrong-password" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_equal "github", user.reload.provider
    assert_match(/Current password is incorrect/i, response.body)
  end

  test "does not unlink an unknown provider" do
    user = create(:user, :github_connected, password: "password123")
    raw_token = issue_token(user)

    delete api_v1_external_authentication_path("google"),
      params: { external_authentication: { current_password: "password123" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_equal "github", user.reload.provider
  end

  private

  def issue_token(user)
    ApiTokenIssuer.new.issue(user: user, attributes: { name: "API", expires_in_days: "" }).raw_token
  end

  def json_headers(raw_token)
    {
      "Accept" => "application/json",
      "Authorization" => "Bearer #{raw_token}"
    }
  end
end
