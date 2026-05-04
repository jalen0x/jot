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
    assert_equal 1, account_json.fetch("display_order")
    assert_equal 1, account_json.fetch("icon_key")
    assert_equal "22C55E", account_json.fetch("color_hex")
    assert_equal false, account_json.fetch("hidden")
    assert_equal "Wallet", account_json.fetch("comment")
    refute_includes account_json.keys, "user_id"
  end

  test "creates an account for the token owner" do
    user = create(:user)
    create_account(user: user, name: "Cash", balance_cents: 0)
    raw_token = issue_token(user)

    post api_v1_accounts_path,
      params: {
        account: {
          name: "Checking",
          account_category: "checking_account",
          account_structure: "single_account",
          icon_key: "2",
          color_hex: "#22c55e",
          currency_code: "usd",
          opening_balance_cents: "12300",
          comment: "Main bank"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :created
    account = user.accounts.where(name: "Checking").sole
    assert_equal "checking_account", account.account_category
    assert_equal "single_account", account.account_structure
    assert_equal 2, account.icon_key
    assert_equal "22C55E", account.color_hex
    assert_equal "USD", account.currency_code
    assert_equal 12_300, account.balance_cents
    assert_equal 2, account.display_order

    opening_balance = user.transactions.balance_adjustment.sole
    assert_equal account, opening_balance.account
    assert_equal 12_300, opening_balance.source_amount_cents

    body = JSON.parse(response.body)
    account_json = body.fetch("account")
    assert_equal account.to_param, account_json.fetch("id")
    assert_equal "Checking", account_json.fetch("name")
    assert_equal 12_300, account_json.fetch("balance_cents")
    assert_equal "checking_account", account_json.fetch("account_category")
    assert_equal "single_account", account_json.fetch("account_structure")
    assert_equal 2, account_json.fetch("icon_key")
    assert_equal "22C55E", account_json.fetch("color_hex")
    assert_equal "USD", account_json.fetch("currency_code")
    assert_equal "Main bank", account_json.fetch("comment")
    refute_includes account_json.keys, "user_id"
  end

  test "updates an account for the token owner" do
    user = create(:user)
    account = create_account(user: user, name: "Checking", balance_cents: 12_300)
    raw_token = issue_token(user)

    patch api_v1_account_path(account),
      params: {
        account: {
          name: "Everyday Checking",
          account_category: "savings_account",
          account_structure: "single_account",
          icon_key: "3",
          color_hex: "#f97316",
          currency_code: "eur",
          comment: "Primary account",
          hidden: "true"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :success
    account.reload
    assert_equal "Everyday Checking", account.name
    assert_equal "savings_account", account.account_category
    assert_equal "single_account", account.account_structure
    assert_equal 3, account.icon_key
    assert_equal "F97316", account.color_hex
    assert_equal "EUR", account.currency_code
    assert_equal "Primary account", account.comment
    assert_equal true, account.hidden
    assert_equal 12_300, account.balance_cents

    account_json = JSON.parse(response.body).fetch("account")
    assert_equal account.to_param, account_json.fetch("id")
    assert_equal "Everyday Checking", account_json.fetch("name")
    assert_equal "savings_account", account_json.fetch("account_category")
    assert_equal 3, account_json.fetch("icon_key")
    assert_equal "F97316", account_json.fetch("color_hex")
    assert_equal "EUR", account_json.fetch("currency_code")
    assert_equal "Primary account", account_json.fetch("comment")
    assert_equal true, account_json.fetch("hidden")
    assert_equal 12_300, account_json.fetch("balance_cents")
    refute_includes account_json.keys, "user_id"
  end

  test "rejects invalid account update params" do
    user = create(:user)
    account = create_account(user: user, name: "Checking", balance_cents: 12_300)
    raw_token = issue_token(user)

    patch api_v1_account_path(account),
      params: {
        account: {
          name: "",
          account_category: "checking_account",
          account_structure: "single_account",
          icon_key: "3",
          color_hex: "F97316",
          currency_code: "USD",
          comment: "Primary account",
          hidden: "false"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_equal "Checking", account.reload.name
    assert_match(/Name/i, response.body)
  end

  test "does not update another user's account" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: other_user, name: "Other", balance_cents: 50_000)
    raw_token = issue_token(user)

    patch api_v1_account_path(account),
      params: {
        account: {
          name: "Changed",
          account_category: "checking_account",
          account_structure: "single_account",
          icon_key: "3",
          color_hex: "F97316",
          currency_code: "USD",
          comment: "Changed",
          hidden: "true"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_equal "Other", account.reload.name
    assert_equal false, account.hidden
  end

  test "deletes an account for the token owner" do
    user = create(:user)
    account = create_account(user: user, name: "Checking", balance_cents: 12_300)
    raw_token = issue_token(user)

    delete api_v1_account_path(account), headers: json_headers(raw_token)

    assert_response :no_content
    assert_empty response.body
    assert_predicate account.reload, :discarded?
  end

  test "does not delete another user's account" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: other_user, name: "Other", balance_cents: 50_000)
    raw_token = issue_token(user)

    delete api_v1_account_path(account), headers: json_headers(raw_token)

    assert_response :not_found
    refute_predicate account.reload, :discarded?
  end

  test "rejects invalid account params" do
    user = create(:user)
    raw_token = issue_token(user)

    post api_v1_accounts_path,
      params: {
        account: {
          name: "",
          account_category: "checking_account",
          account_structure: "single_account",
          icon_key: "2",
          color_hex: "22C55E",
          currency_code: "USD",
          opening_balance_cents: "12300",
          comment: "Main bank"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_empty user.accounts.where(account_category: :checking_account)
    assert_empty user.transactions.balance_adjustment
    assert_match(/Name/i, response.body)
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
      display_order: 1,
      comment: "Wallet"
    )
  end
end
