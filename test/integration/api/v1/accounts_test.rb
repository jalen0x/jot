require "test_helper"

class ApiV1AccountsTest < ActionDispatch::IntegrationTest
  test "lists only the token owner's kept accounts" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking", balance_cents: 12_300)
    discarded_account = create_account(user: user, name: "Closed", balance_cents: 9_999)
    discarded_account.discard!
    create_account(user: other_user, name: "Other", balance_cents: 50_000)
    raw_token = issue_token(user)

    get api_v1_accounts_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "accounts" ], body.keys
    assert_equal [ account.to_param ], body.fetch("accounts").map { |item| item.fetch("id") }
    account_json = body.fetch("accounts").first
    assert_equal "Checking", account_json.fetch("name")
    assert_equal "cash", account_json.fetch("account_category")
    assert_equal "single_account", account_json.fetch("account_structure")
    assert_equal "USD", account_json.fetch("currency_code")
    assert_equal 12_300, account_json.fetch("balance_cents")
    refute_includes account_json.keys, "user_id"
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

  def create_account(user:, name:, balance_cents:)
    Account.create!(
      user: user,
      name: name,
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: balance_cents,
      display_order: 1
    )
  end
end
