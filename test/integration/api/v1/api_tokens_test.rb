require "test_helper"

class ApiV1ApiTokensTest < ActionDispatch::IntegrationTest
  test "lists only the token owner's active tokens" do
    user = create(:user)
    raw_token = issue_token(user, name: "Auth")
    create_token(user: user, name: "Active")
    create_token(user: user, name: "Expired", expires_at: 1.minute.ago)
    revoked = create_token(user: user, name: "Revoked")
    revoked.discard!
    create_token(user: create(:user), name: "Other")

    get api_v1_api_tokens_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "api_tokens" ], body.keys
    api_tokens = body.fetch("api_tokens")
    names = api_tokens.map { |api_token| api_token.fetch("name") }
    assert_includes names, "Auth"
    assert_includes names, "Active"
    refute_includes names, "Expired"
    refute_includes names, "Revoked"
    refute_includes names, "Other"
    api_tokens.each do |api_token|
      assert api_token.fetch("id").start_with?("tok_")
      assert_equal true, api_token.fetch("active")
      refute_includes api_token.keys, "token_digest"
      refute_includes api_token.keys, "raw_token"
      refute_includes api_token.keys, "user_id"
    end
  end

  test "issues a raw token once after current password verification" do
    user = create(:user, password: "password123")
    raw_token = issue_token(user, name: "Auth")

    with_stubbed_token("raw-token-123") do
      post api_v1_api_tokens_path,
        params: { api_token: { name: "CLI", expires_in_days: "30", current_password: "password123" } },
        headers: json_headers(raw_token),
        as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "raw-token-123", body.fetch("raw_token")
    api_token = user.api_tokens.find_by!(name: "CLI")
    assert api_token.matches_token?("raw-token-123")
    refute_equal "raw-token-123", api_token.token_digest
    assert_equal api_token.to_param, body.dig("api_token", "id")
    refute_includes body.fetch("api_token").keys, "token_digest"
  end

  test "rejects token issuance with an incorrect password" do
    user = create(:user, password: "password123")
    raw_token = issue_token(user, name: "Auth")

    post api_v1_api_tokens_path,
      params: { api_token: { name: "CLI", expires_in_days: "30", current_password: "wrong-password" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_nil user.api_tokens.find_by(name: "CLI")
    assert_match(/Current password is incorrect/i, response.body)
  end

  test "revokes the token owner's token" do
    user = create(:user)
    raw_token = issue_token(user, name: "Auth")
    api_token = create_token(user: user, name: "CLI")

    delete api_v1_api_token_path(api_token), headers: json_headers(raw_token)

    assert_response :no_content
    assert_empty response.body
    assert_predicate api_token.reload, :discarded?
  end

  test "does not revoke another user's token" do
    user = create(:user)
    raw_token = issue_token(user, name: "Auth")
    other_token = create_token(user: create(:user), name: "Other")

    delete api_v1_api_token_path(other_token), headers: json_headers(raw_token)

    assert_response :not_found
    assert_predicate other_token.reload, :kept?
  end

  private

  def issue_token(user, name:)
    ApiTokenIssuer.new.issue(user: user, attributes: { name: name, expires_in_days: "" }).raw_token
  end

  def json_headers(raw_token)
    {
      "Accept" => "application/json",
      "Authorization" => "Bearer #{raw_token}"
    }
  end

  def create_token(user:, name:, expires_at: 1.day.from_now)
    ApiToken.create!(
      user: user,
      name: name,
      token_digest: BCrypt::Password.create("raw-token"),
      expires_at: expires_at
    )
  end

  def with_stubbed_token(raw_token)
    original = SecureRandom.method(:urlsafe_base64)
    SecureRandom.define_singleton_method(:urlsafe_base64) { |*| raw_token }
    yield
  ensure
    SecureRandom.define_singleton_method(:urlsafe_base64, original)
  end
end
