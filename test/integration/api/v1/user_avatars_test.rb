require "test_helper"

class ApiV1UserAvatarsTest < ActionDispatch::IntegrationTest
  test "uploads the token owner's avatar" do
    user = create(:user)
    other_user = create(:user)
    other_user.avatar.attach(io: StringIO.new("other"), filename: "other.png", content_type: "image/png", identify: false)
    raw_token = issue_token(user)

    post api_v1_user_avatar_path,
      params: { avatar: fixture_file_upload("avatar.png", "image/png") },
      headers: json_headers(raw_token)

    assert_response :created
    assert_predicate user.reload.avatar, :attached?
    assert_predicate other_user.reload.avatar, :attached?
    body = JSON.parse(response.body)
    assert_equal [ "user_profile" ], body.keys
    profile = body.fetch("user_profile")
    assert_equal true, profile.fetch("avatar_attached")
    refute_includes profile.keys, "user_id"
  end

  test "removes the token owner's avatar" do
    user = create(:user)
    user.avatar.attach(io: StringIO.new("avatar"), filename: "avatar.png", content_type: "image/png", identify: false)
    other_user = create(:user)
    other_user.avatar.attach(io: StringIO.new("other"), filename: "other.png", content_type: "image/png", identify: false)
    raw_token = issue_token(user)

    delete api_v1_user_avatar_path, headers: json_headers(raw_token)

    assert_response :no_content
    assert_empty response.body
    refute_predicate user.reload.avatar, :attached?
    assert_predicate other_user.reload.avatar, :attached?
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
