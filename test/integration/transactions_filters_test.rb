require "test_helper"

class TransactionsFiltersTest < ActionDispatch::IntegrationTest
  test "filters transactions by type and category" do
    user = create(:user)
    account = create_account(user: user, name: "Cash")
    income_category = create_category(user: user, name: "Salary", category_type: :income)
    expense_category = create_category(user: user, name: "Food", category_type: :expense)
    create_transaction(user: user, account: account, category: income_category, transaction_kind: :income, comment: "Paycheck")
    create_transaction(user: user, account: account, category: expense_category, transaction_kind: :expense, comment: "Groceries")
    create_transaction(user: create(:user), comment: "Other Paycheck")
    sign_in user

    get transactions_path, params: { transaction_kind: "income", transaction_category_id: income_category.id.to_s }

    assert_response :success
    assert_select "form[action='#{transactions_path}'][method='get']"
    assert_select "li", text: /Paycheck/i
    assert_select "li", text: /Groceries/i, count: 0
    assert_select "li", text: /Other Paycheck/i, count: 0
  end

  test "filters transactions by account and tag" do
    user = create(:user)
    matching_account = create_account(user: user, name: "Business Checking")
    other_account = create_account(user: user, name: "Personal Cash")
    category = create_category(user: user, name: "Food", category_type: :expense)
    matching_tag = create_tag(user: user, name: "Business")
    other_tag = create_tag(user: user, name: "Personal")
    matching = create_transaction(user: user, account: matching_account, category: category, transaction_kind: :expense, comment: "Client lunch")
    other = create_transaction(user: user, account: other_account, category: category, transaction_kind: :expense, comment: "Family lunch")
    TransactionTagging.create!(user: user, ledger_transaction: matching, transaction_tag: matching_tag)
    TransactionTagging.create!(user: user, ledger_transaction: other, transaction_tag: other_tag)
    sign_in user

    get transactions_path, params: { account_id: matching_account.id.to_s, tag_id: matching_tag.id.to_s }

    assert_response :success
    assert_select "li", text: /Client lunch/i
    assert_select "li", text: /Family lunch/i, count: 0
  end

  private

  def create_transaction(user:, comment:, account: nil, category: nil, transaction_kind: :expense)
    account ||= create_account(user: user, name: "Cash #{comment}")
    category ||= create_category(user: user, name: "Food #{comment}", category_type: transaction_kind)

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: transaction_kind,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1000,
      destination_amount_cents: 0,
      comment: comment
    )
  end

  def create_account(user:, name:)
    Account.create!(
      user: user,
      name: name,
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
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

  def create_tag(user:, name:)
    TransactionTag.create!(user: user, name: name, display_order: 1)
  end
end
