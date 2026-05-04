require "test_helper"

class ApiV1TransactionAmountSummariesTest < ActionDispatch::IntegrationTest
  test "returns income and expense amounts by currency for the token owner" do
    user = create(:user)
    other_user = create(:user)
    usd_account = create_account(user: user, name: "Checking", currency_code: "USD")
    cny_account = create_account(user: user, name: "Cash", currency_code: "CNY")
    create_transaction(user: user, account: usd_account, transaction_kind: :income, source_amount_cents: 5_000, transacted_at: Time.zone.parse("2026-05-03 09:00:00"))
    create_transaction(user: user, account: usd_account, transaction_kind: :expense, source_amount_cents: 1_200, transacted_at: Time.zone.parse("2026-05-04 09:00:00"))
    create_transaction(user: user, account: cny_account, transaction_kind: :income, source_amount_cents: 700, transacted_at: Time.zone.parse("2026-05-05 09:00:00"))
    create_transaction(user: other_user, account: create_account(user: other_user, name: "Other", currency_code: "USD"), transaction_kind: :income, source_amount_cents: 7_777, transacted_at: Time.zone.parse("2026-05-03 09:00:00"))
    raw_token = issue_token(user)

    get api_v1_transaction_amount_summary_path,
      params: { start_date: "2026-05-01", end_date: "2026-05-31" },
      headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "transaction_amount_summary" ], body.keys
    assert_equal [
      { "currency_code" => "CNY", "income_cents" => 700, "expense_cents" => 0, "net_cents" => 700 },
      { "currency_code" => "USD", "income_cents" => 5_000, "expense_cents" => 1_200, "net_cents" => 3_800 }
    ], body.fetch("transaction_amount_summary").fetch("amounts")
  end

  test "rejects invalid transaction amount summary dates" do
    user = create(:user)
    raw_token = issue_token(user)

    get api_v1_transaction_amount_summary_path,
      params: { start_date: "not-a-date", end_date: "2026-05-31" },
      headers: json_headers(raw_token)

    assert_response :unprocessable_content
    assert_match(/valid ISO 8601 dates/i, response.body)
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

  def create_account(user:, name:, currency_code:)
    Account.create!(
      user: user,
      name: name,
      account_category: :checking_account,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: currency_code,
      balance_cents: 0,
      display_order: 1
    )
  end

  def create_transaction(user:, account:, transaction_kind:, source_amount_cents:, transacted_at:)
    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category_for(user, transaction_kind),
      transaction_kind: transaction_kind,
      transacted_at: transacted_at,
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: 0,
      comment: transaction_kind.to_s.humanize
    )
  end

  def category_for(user, transaction_kind)
    TransactionCategory.create!(
      user: user,
      name: transaction_kind.to_s.humanize,
      category_type: transaction_kind,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end
end
