require "test_helper"

class ApiV1LedgerClearancesTest < ActionDispatch::IntegrationTest
  test "clears the token owner's transactions" do
    user = create(:user, password: "password123")
    account = create_account(user: user, balance_cents: 2_000)
    category = create_category(user: user)
    transaction = create_transaction(user: user, account: account, category: category)
    raw_token = issue_token(user)

    post api_v1_ledger_clearances_path,
      params: { ledger_clearance: { clearance_scope: "transactions", current_password: "password123" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "transactions", body.fetch("ledger_clearance").fetch("clearance_scope")
    assert_predicate transaction.reload, :discarded?
    assert_equal 0, account.reload.balance_cents
    assert_predicate category.reload, :kept?
  end

  test "clears all token owner ledger data" do
    user = create(:user, password: "password123")
    account = create_account(user: user, balance_cents: 2_000)
    category = create_category(user: user)
    transaction = create_transaction(user: user, account: account, category: category)
    raw_token = issue_token(user)

    post api_v1_ledger_clearances_path,
      params: { ledger_clearance: { clearance_scope: "all", current_password: "password123" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "all", body.fetch("ledger_clearance").fetch("clearance_scope")
    assert_predicate transaction.reload, :discarded?
    assert_predicate account.reload, :discarded?
    assert_predicate category.reload, :discarded?
  end

  test "rejects an incorrect password" do
    user = create(:user, password: "password123")
    account = create_account(user: user, balance_cents: 2_000)
    transaction = create_transaction(user: user, account: account)
    raw_token = issue_token(user)

    post api_v1_ledger_clearances_path,
      params: { ledger_clearance: { clearance_scope: "transactions", current_password: "wrong-password" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_match(/password/i, response.body)
    assert_predicate transaction.reload, :kept?
    assert_equal 2_000, account.reload.balance_cents
  end

  test "rejects an invalid clearance scope" do
    user = create(:user, password: "password123")
    account = create_account(user: user, balance_cents: 2_000)
    transaction = create_transaction(user: user, account: account)
    raw_token = issue_token(user)

    post api_v1_ledger_clearances_path,
      params: { ledger_clearance: { clearance_scope: "everything", current_password: "password123" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_match(/Clearance scope/i, response.body)
    assert_predicate transaction.reload, :kept?
    assert_equal 2_000, account.reload.balance_cents
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

  def create_account(user:, balance_cents: 0)
    Account.create!(
      user: user,
      name: "Cash",
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: balance_cents,
      display_order: 1
    )
  end

  def create_category(user:)
    TransactionCategory.create!(
      user: user,
      name: "Food",
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end

  def create_transaction(user:, account:, category: create_category(user: user))
    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1_200,
      destination_amount_cents: 0,
      comment: "Clear from API"
    )
  end
end
