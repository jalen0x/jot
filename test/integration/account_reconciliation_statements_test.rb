require "test_helper"

class AccountReconciliationStatementsTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    account = create_account(user: create(:user), name: "Checking")

    get account_reconciliation_statement_path(account)

    assert_redirected_to new_user_session_path
  end

  test "shows a reconciliation statement for the signed-in user's account" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    create_transaction(user: user, account: account, transaction_kind: :balance_adjustment, source_amount_cents: 5_000, transacted_at: Time.zone.parse("2026-05-01 09:00:00"))
    income = create_transaction(user: user, account: account, transaction_kind: :income, source_amount_cents: 2_000, transacted_at: Time.zone.parse("2026-05-03 09:00:00"))
    expense = create_transaction(user: user, account: account, transaction_kind: :expense, source_amount_cents: 1_200, transacted_at: Time.zone.parse("2026-05-03 10:00:00"))
    create_transaction(user: user, account: account, transaction_kind: :income, source_amount_cents: 9_999, transacted_at: Time.zone.parse("2026-05-04 09:00:00"))
    other_user = create(:user)
    create_transaction(user: other_user, account: create_account(user: other_user, name: "Other"), transaction_kind: :income, source_amount_cents: 9_999, transacted_at: Time.zone.parse("2026-05-03 09:00:00"))
    sign_in user

    get account_reconciliation_statement_path(account), params: { start_date: "2026-05-03", end_date: "2026-05-03" }

    assert_response :success
    assert_match(/Checking/, response.body)
    assert_match(/50.00 USD/, response.body)
    assert_match(/20.00 USD/, response.body)
    assert_match(/12.00 USD/, response.body)
    assert_match(/58.00 USD/, response.body)
    assert_match(/#{income.comment}/, response.body)
    assert_match(/#{expense.comment}/, response.body)
    refute_match(/99.99 USD/, response.body)
  end

  test "does not show another user's account reconciliation statement" do
    user = create(:user)
    account = create_account(user: create(:user), name: "Other Checking")
    sign_in user

    get account_reconciliation_statement_path(account), params: { start_date: "2026-05-03", end_date: "2026-05-03" }

    assert_response :not_found
  end

  test "rejects invalid date params" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    sign_in user

    get account_reconciliation_statement_path(account), params: { start_date: "not-a-date", end_date: "2026-05-03" }

    assert_response :unprocessable_content
    assert_match(/valid ISO 8601 dates/i, response.body)
  end

  private

  def create_account(user:, name:)
    Account.create!(
      user: user,
      name: name,
      account_category: :checking_account,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
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
