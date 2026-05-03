require "test_helper"

class ApiContentNegotiationTest < ActionDispatch::IntegrationTest
  test "requires json requests" do
    raw_token = issue_token(create(:user))

    get api_v1_accounts_path, headers: { "Accept" => "text/html", "Authorization" => "Bearer #{raw_token}" }

    assert_response :not_acceptable
  end

  private

  def issue_token(user)
    ApiTokenIssuer.new.issue(user: user, attributes: { name: "API", expires_in_days: "" }).raw_token
  end
end
