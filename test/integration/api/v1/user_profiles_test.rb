require "test_helper"

class ApiV1UserProfilesTest < ActionDispatch::IntegrationTest
  test "shows the token owner's profile" do
    user = create(:user, email: "jalen@example.com", first_name: "Jalen", last_name: "X")
    raw_token = issue_token(user)

    get api_v1_user_profile_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "user_profile" ], body.keys
    profile = body.fetch("user_profile")
    assert_equal "jalen@example.com", profile.fetch("email")
    assert_equal "Jalen", profile.fetch("first_name")
    assert_equal "X", profile.fetch("last_name")
    assert_equal "Jalen X", profile.fetch("name")
    assert_equal false, profile.fetch("avatar_attached")
    refute_includes profile.keys, "user_id"
    refute_includes profile.keys, "encrypted_password"
  end

  test "updates only display profile attributes" do
    user = create(:user, email: "jalen@example.com", first_name: "Old", last_name: "Name")
    raw_token = issue_token(user)

    patch api_v1_user_profile_path,
      params: { user_profile: { first_name: "New", last_name: "Display", email: "changed@example.com" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :success
    body = JSON.parse(response.body)
    profile = body.fetch("user_profile")
    assert_equal "New", profile.fetch("first_name")
    assert_equal "Display", profile.fetch("last_name")
    assert_equal "New Display", profile.fetch("name")
    assert_equal "jalen@example.com", profile.fetch("email")
    user.reload
    assert_equal "New", user.first_name
    assert_equal "Display", user.last_name
    assert_equal "jalen@example.com", user.email
  end

  private

  def issue_token(user)
    ApiTokenIssuer.new.issue(user: user, attributes: { name: "Auth", expires_in_days: "" }).raw_token
  end

  def json_headers(raw_token)
    {
      "Accept" => "application/json",
      "Authorization" => "Bearer #{raw_token}"
    }
  end
end
