require "test_helper"

class ApiAuthenticationTest < ActionDispatch::IntegrationTest
  test "requires a bearer token" do
    get api_v1_accounts_path, headers: json_headers

    assert_response :unauthorized
  end

  test "rejects an invalid bearer token" do
    get api_v1_accounts_path, headers: json_headers.merge("Authorization" => "Bearer wrong-token")

    assert_response :unauthorized
  end

  private

  def json_headers
    { "Accept" => "application/json" }
  end
end
