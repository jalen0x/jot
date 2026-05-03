require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "matches a raw token against its digest" do
    api_token = ApiToken.new(
      user: create(:user),
      name: "Mobile client",
      token_digest: BCrypt::Password.create("raw-token"),
      expires_at: 1.day.from_now
    )

    assert api_token.matches_token?("raw-token")
    refute api_token.matches_token?("wrong-token")
  end

  test "reports active only for kept unexpired tokens" do
    active = ApiToken.new(user: create(:user), name: "Active", token_digest: BCrypt::Password.create("raw-token"), expires_at: 1.day.from_now)
    expired = ApiToken.new(user: create(:user), name: "Expired", token_digest: BCrypt::Password.create("raw-token"), expires_at: 1.minute.ago)
    never_expires = ApiToken.new(user: create(:user), name: "No expiry", token_digest: BCrypt::Password.create("raw-token"))
    revoked = ApiToken.new(user: create(:user), name: "Revoked", token_digest: BCrypt::Password.create("raw-token"), expires_at: 1.day.from_now, discarded_at: Time.current)

    assert_predicate active, :active?
    refute_predicate expired, :active?
    assert_predicate never_expires, :active?
    refute_predicate revoked, :active?
  end

  test "requires a name" do
    api_token = ApiToken.new(user: create(:user), token_digest: BCrypt::Password.create("raw-token"))

    refute_predicate api_token, :valid?
    assert_includes api_token.errors[:name], "can't be blank"
  end
end
