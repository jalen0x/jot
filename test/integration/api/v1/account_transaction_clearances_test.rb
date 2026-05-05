require "test_helper"

class ApiV1AccountTransactionClearancesTest < ActionDispatch::IntegrationTest
  test "clears transactions for the token owner's account" do
    user = create(:user, password: "password123")
    account = create_account(user: user, name: "Checking", balance_cents: -800)
    other_account = create_account(user: user, name: "Savings", balance_cents: 2_000)
    category = create_category(user: user, category_type: :expense)
    transaction = create_transaction(user: user, account: account, category: category, source_amount_cents: 800)
    other_transaction = create_transaction(user: user, account: other_account, category: category, source_amount_cents: 500)
    raw_token = issue_token(user)

    post api_v1_account_transaction_clearance_path(account),
      params: { account_transaction_clearance: { current_password: "password123" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal account.to_param, body.fetch("account_transaction_clearance").fetch("account_id")
    assert_predicate transaction.reload, :discarded?
    assert_predicate other_transaction.reload, :kept?
    assert_equal 0, account.reload.balance_cents
    assert_equal 2_000, other_account.reload.balance_cents
  end

  test "rejects an incorrect password" do
    user = create(:user, password: "password123")
    account = create_account(user: user, name: "Checking", balance_cents: -800)
    category = create_category(user: user, category_type: :expense)
    transaction = create_transaction(user: user, account: account, category: category, source_amount_cents: 800)
    raw_token = issue_token(user)

    post api_v1_account_transaction_clearance_path(account),
      params: { account_transaction_clearance: { current_password: "wrong-password" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_match(/password/i, response.body)
    assert_predicate transaction.reload, :kept?
    assert_equal(-800, account.reload.balance_cents)
  end

  test "does not clear another user's account" do
    user = create(:user, password: "password123")
    other_user = create(:user, password: "password123")
    account = create_account(user: other_user, name: "Other Checking", balance_cents: 800)
    category = create_category(user: other_user, category_type: :expense)
    transaction = create_transaction(user: other_user, account: account, category: category, source_amount_cents: 800)
    raw_token = issue_token(user)

    post api_v1_account_transaction_clearance_path(account),
      params: { account_transaction_clearance: { current_password: "password123" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_predicate transaction.reload, :kept?
    assert_equal 800, account.reload.balance_cents
  end

  test "rejects hidden accounts" do
    user = create(:user, password: "password123")
    account = create_account(user: user, name: "Hidden Checking", balance_cents: -800, hidden: true)
    category = create_category(user: user, category_type: :expense)
    transaction = create_transaction(user: user, account: account, category: category, source_amount_cents: 800)
    raw_token = issue_token(user)

    post api_v1_account_transaction_clearance_path(account),
      params: { account_transaction_clearance: { current_password: "password123" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_match(/hidden account/i, response.body)
    assert_predicate transaction.reload, :kept?
    assert_equal(-800, account.reload.balance_cents)
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

  def create_account(user:, name:, balance_cents:, hidden: false, account_structure: :single_account)
    Account.create!(
      user: user,
      name: name,
      account_category: :cash,
      account_structure: account_structure,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: balance_cents,
      hidden: hidden,
      display_order: 1
    )
  end

  def create_category(user:, category_type:)
    TransactionCategory.create!(
      user: user,
      name: category_type.to_s.humanize,
      category_type: category_type,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end

  def create_transaction(user:, account:, category:, source_amount_cents:)
    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: 0,
      comment: "Clear by account"
    )
  end
end
