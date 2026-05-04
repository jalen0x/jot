require "test_helper"

class ApiV1AccountBalanceTrendsTest < ActionDispatch::IntegrationTest
  test "returns daily account balance trends for the token owner" do
    user = create(:user)
    other_user = create(:user)
    checking = create_account(user: user, name: "Checking", display_order: 1)
    savings = create_account(user: user, name: "Savings", display_order: 2)
    create_transaction(user: user, account: checking, transaction_kind: :balance_adjustment, source_amount_cents: 5_000, transacted_at: Time.zone.parse("2026-05-01 09:00:00"))
    create_transaction(user: user, account: savings, transaction_kind: :balance_adjustment, source_amount_cents: 1_000, transacted_at: Time.zone.parse("2026-05-01 10:00:00"))
    create_transaction(user: user, account: checking, transaction_kind: :income, source_amount_cents: 2_000, transacted_at: Time.zone.parse("2026-05-03 09:00:00"))
    create_transaction(user: user, account: checking, transaction_kind: :expense, source_amount_cents: 1_200, transacted_at: Time.zone.parse("2026-05-03 10:00:00"))
    create_transaction(user: user, account: checking, destination_account: savings, transaction_kind: :transfer, source_amount_cents: 1_500, destination_amount_cents: 1_500, transacted_at: Time.zone.parse("2026-05-03 11:00:00"))
    create_transaction(user: user, account: savings, transaction_kind: :expense, source_amount_cents: 300, transacted_at: Time.zone.parse("2026-05-04 09:00:00"))
    create_transaction(user: other_user, account: create_account(user: other_user, name: "Other Checking", display_order: 1), transaction_kind: :income, source_amount_cents: 8_888, transacted_at: Time.zone.parse("2026-05-03 09:00:00"))
    raw_token = issue_token(user)

    get api_v1_account_balance_trends_path,
      params: { start_date: "2026-05-03", end_date: "2026-05-04" },
      headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "account_balance_trends" ], body.keys
    assert_equal [
      {
        "starts_on" => "2026-05-03",
        "account_balances" => [
          { "account_id" => checking.to_param, "opening_balance_cents" => 5_000, "closing_balance_cents" => 4_300 },
          { "account_id" => savings.to_param, "opening_balance_cents" => 1_000, "closing_balance_cents" => 2_500 }
        ]
      },
      {
        "starts_on" => "2026-05-04",
        "account_balances" => [
          { "account_id" => checking.to_param, "opening_balance_cents" => 4_300, "closing_balance_cents" => 4_300 },
          { "account_id" => savings.to_param, "opening_balance_cents" => 2_500, "closing_balance_cents" => 2_200 }
        ]
      }
    ], body.fetch("account_balance_trends").fetch("buckets")
  end

  test "rejects invalid account balance trend dates" do
    user = create(:user)
    raw_token = issue_token(user)

    get api_v1_account_balance_trends_path,
      params: { start_date: "not-a-date", end_date: "2026-05-04" },
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

  def create_account(user:, name:, display_order:)
    Account.create!(
      user: user,
      name: name,
      account_category: :checking_account,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: 0,
      display_order: display_order
    )
  end

  def create_transaction(user:, account:, transaction_kind:, source_amount_cents:, transacted_at:, destination_account: nil, destination_amount_cents: 0)
    Transaction.create!(
      user: user,
      account: account,
      destination_account: destination_account,
      transaction_category: category_for(user, transaction_kind),
      transaction_kind: transaction_kind,
      transacted_at: transacted_at,
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: destination_amount_cents,
      comment: transaction_kind.to_s.humanize
    )
  end

  def category_for(user, transaction_kind)
    return if transaction_kind.to_s == "balance_adjustment"

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
