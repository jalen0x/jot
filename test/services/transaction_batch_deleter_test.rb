require "test_helper"

class TransactionBatchDeleterTest < ActiveSupport::TestCase
  test "deletes multiple transactions and reverses balances" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 10_750)
    income_category = create_category(user: user, name: "Salary", category_type: :income)
    expense_category = create_category(user: user, name: "Food", category_type: :expense)
    income = create_transaction(user: user, account: account, category: income_category, transaction_kind: :income, source_amount_cents: 2_000, comment: "Paycheck")
    expense = create_transaction(user: user, account: account, category: expense_category, transaction_kind: :expense, source_amount_cents: 1_250, comment: "Lunch")

    result = TransactionBatchDeleter.new.delete_transactions(transactions: [ income, expense ])

    assert_predicate result, :deleted?
    assert_predicate income.reload, :discarded?
    assert_predicate expense.reload, :discarded?
    assert_equal 10_000, account.reload.balance_cents
  end

  test "rejects deletions outside the user's transaction edit scope without partial deletes" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD", transaction_edit_scope: "today_or_later")
    account = create_account(user: user, balance_cents: 10_750)
    income_category = create_category(user: user, name: "Salary", category_type: :income)
    expense_category = create_category(user: user, name: "Food", category_type: :expense)
    income = create_transaction(user: user, account: account, category: income_category, transaction_kind: :income, source_amount_cents: 2_000, comment: "Paycheck")
    expense = create_transaction(user: user, account: account, category: expense_category, transaction_kind: :expense, source_amount_cents: 1_250, comment: "Lunch")

    travel_to Time.zone.parse("2026-05-04 12:00:00") do
      result = TransactionBatchDeleter.new.delete_transactions(transactions: [ income, expense ])

      refute_predicate result, :deleted?
      assert_includes result.transaction.errors[:base], "Transaction is outside the editable date range"
    end
    refute_predicate income.reload, :discarded?
    refute_predicate expense.reload, :discarded?
    assert_equal 10_750, account.reload.balance_cents
  end

  private

  def create_account(user:, balance_cents: 0)
    Account.create!(
      user: user,
      name: "Checking",
      account_category: :checking_account,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: balance_cents,
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

  def create_transaction(user:, account:, category:, transaction_kind:, source_amount_cents:, comment:)
    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: transaction_kind,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: 0,
      comment: comment
    )
  end
end
