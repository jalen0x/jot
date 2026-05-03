require "test_helper"

class ApiTokenIssuerTest < ActiveSupport::TestCase
  test "issues a raw token and stores only its digest" do
    result = ApiTokenIssuer.new.issue(
      user: create(:user),
      attributes: { name: "Mobile client", expires_in_days: "7" }
    )

    assert_predicate result, :issued?
    assert_not_empty result.raw_token
    refute_equal result.raw_token, result.api_token.token_digest
    assert result.api_token.matches_token?(result.raw_token)
    assert_equal "Mobile client", result.api_token.name
    assert_in_delta 7.days.from_now.to_i, result.api_token.expires_at.to_i, 2
  end

  test "supports tokens without expiration" do
    result = ApiTokenIssuer.new.issue(
      user: create(:user),
      attributes: { name: "CLI", expires_in_days: "" }
    )

    assert_predicate result, :issued?
    assert_nil result.api_token.expires_at
  end

  test "returns validation errors" do
    result = ApiTokenIssuer.new.issue(
      user: create(:user),
      attributes: { name: "", expires_in_days: "" }
    )

    refute_predicate result, :issued?
    assert_includes result.api_token.errors[:name], "can't be blank"
    assert_nil result.raw_token
  end
end
