require "test_helper"

class ApiV1SystemVersionsTest < ActionDispatch::IntegrationTest
  test "shows version metadata for the token owner" do
    user = create(:user)
    raw_token = issue_token(user)

    with_env(
      "APP_VERSION" => "2026.5.4",
      "APP_COMMIT_HASH" => "abc123",
      "APP_BUILD_TIME" => "2026-05-04T10:00:00Z"
    ) do
      get api_v1_system_version_path, headers: json_headers(raw_token)
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "system_version" ], body.keys
    system_version = body.fetch("system_version")
    assert_equal "2026.5.4", system_version.fetch("version")
    assert_equal "abc123", system_version.fetch("commit_hash")
    assert_equal "2026-05-04T10:00:00Z", system_version.fetch("build_time")
    refute_includes system_version.keys, "user_id"
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

  def with_env(values)
    original = values.keys.to_h { |key| [ key, ENV[key] ] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
