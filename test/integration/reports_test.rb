require "test_helper"

class ReportsTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get reports_path

    assert_redirected_to new_user_session_path
  end

  test "shows current user's report totals for selected range" do
    user = create(:user)
    other_user = create(:user)
    salary = create_category(user: user, name: "Salary", category_type: :income)
    food = create_category(user: user, name: "Food", category_type: :expense)
    create_transaction(user: user, category: salary, transaction_kind: :income, amount_cents: 5_000, comment: "Paycheck")
    create_transaction(user: user, category: food, transaction_kind: :expense, amount_cents: 1_200, comment: "Groceries")
    create_transaction(user: user, category: salary, transaction_kind: :income, amount_cents: 700, comment: "Cash gift", currency_code: "CNY")
    create_transaction(user: other_user, transaction_kind: :income, amount_cents: 9_999, comment: "Other Paycheck")
    sign_in user

    get reports_path, params: { start_date: "2026-05-01", end_date: "2026-05-31" }

    assert_response :success
    assert_select "h1", text: /reports/i
    assert_select "p", text: /50.00 USD/
    assert_select "p", text: /12.00 USD/
    assert_select "p", text: /7.00 CNY/
    assert_select "p", text: /57.00/, count: 0
    assert_select "li", text: /Salary/i
    assert_select "li", text: /Salary.*50\.00 USD/m
    assert_select "li", text: /Salary.*7\.00 CNY/m
    assert_select "li", text: /Salary.*57\.00/m, count: 0
    assert_select "li", text: /Food/i
    assert_select "li", text: /Other/i, count: 0
  end

  private

  def create_transaction(user:, transaction_kind:, amount_cents:, comment:, category: nil, currency_code: "USD")
    category ||= create_category(user: user, name: transaction_kind.to_s.humanize, category_type: transaction_kind)
    account = create_account(user: user, currency_code: currency_code)

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: transaction_kind,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: amount_cents,
      destination_amount_cents: 0,
      comment: comment
    )
  end

  def create_account(user:, currency_code: "USD")
    Account.create!(
      user: user,
      name: "Cash",
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: currency_code,
      balance_cents: 0,
      display_order: 1
    )
  end

  def create_category(user:, name:, category_type:)
    TransactionCategory.create!(
      user: user,
      name: name,
      category_type: category_type,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end
end
