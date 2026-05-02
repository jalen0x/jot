require "test_helper"

class TransactionsTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get transactions_path

    assert_redirected_to new_user_session_path
  end

  test "lists only current user transactions" do
    user = create(:user)
    other_user = create(:user)
    transaction = create_transaction(user: user, comment: "Groceries")
    create_transaction(user: other_user, comment: "Other Groceries")

    sign_in user
    get transactions_path

    assert_response :success
    assert_select "h1", text: /transactions/i
    assert_select "li", text: /#{transaction.comment}/i
    assert_select "li", text: /Other Groceries/i, count: 0
  end

  test "creates an expense for current user" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :expense)
    tag = create_tag(user: user, name: "Food")
    sign_in user

    post transactions_path, params: {
      transaction: {
        transaction_kind: "expense",
        account_id: account.id.to_s,
        destination_account_id: "",
        transaction_category_id: category.id.to_s,
        transacted_at: "2026-05-03 10:00:00",
        timezone_utc_offset_minutes: "0",
        source_amount_cents: "1200",
        destination_amount_cents: "0",
        hide_amount: "0",
        comment: "Lunch",
        transaction_tag_ids: [ tag.id.to_s ]
      }
    }

    transaction = user.transactions.where(transaction_kind: :expense).sole
    assert_redirected_to transactions_path
    assert_equal "Lunch", transaction.comment
    assert_equal category, transaction.transaction_category
    assert_equal [ tag ], transaction.transaction_tags.to_a
    assert_equal 3_800, account.reload.balance_cents
  end

  private

  def create_transaction(user:, comment:)
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :expense)

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

  def create_account(user:, balance_cents:, name: "Cash")
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

  def create_tag(user:, name:)
    TransactionTag.create!(user: user, name: name, display_order: 1)
  end
end
