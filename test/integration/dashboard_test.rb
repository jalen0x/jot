require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get dashboard_path

    assert_redirected_to new_user_session_path
  end

  test "shows only current user's ledger summary" do
    user = create(:user)
    other_user = create(:user)
    create_account(user: user, name: "Checking", balance_cents: 4_000)
    create_account(user: user, name: "Wallet", balance_cents: 700, currency_code: "CNY")
    create_transaction(user: user, comment: "Groceries")
    create_account(user: other_user, name: "Other Checking", balance_cents: 9_999)
    create_transaction(user: other_user, comment: "Other Groceries")

    sign_in user
    get dashboard_path

    assert_response :success
    assert_select "h1", text: /dashboard/i
    assert_select "p", text: /40.00 USD/
    assert_select "p", text: /7.00 CNY/
    assert_select "li", text: /Groceries/i
    assert_select "li", text: /10.00 USD/
    assert_select "li", text: /1000 cents/, count: 0
    assert_select "li", text: /Other Groceries/i, count: 0
  end

  private

  def create_account(user:, name:, balance_cents:, currency_code: "USD")
    Account.create!(
      user: user,
      name: name,
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: currency_code,
      balance_cents: balance_cents,
      display_order: 1
    )
  end

  def create_transaction(user:, comment:)
    account = create_account(user: user, name: "Cash #{comment}", balance_cents: 0)
    category = TransactionCategory.create!(
      user: user,
      name: "Food #{comment}",
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1000,
      destination_amount_cents: 0,
      comment: comment
    )
  end
end
