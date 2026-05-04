require "test_helper"

class TransactionBatchCategoryUpdaterTest < ActiveSupport::TestCase
  test "updates categories for multiple transactions" do
    user = create(:user)
    account = create_account(user: user)
    old_category = create_category(user: user, name: "Food", category_type: :expense)
    new_category = create_category(user: user, name: "Travel", category_type: :expense)
    lunch = create_transaction(user: user, account: account, category: old_category, comment: "Lunch")
    coffee = create_transaction(user: user, account: account, category: old_category, comment: "Coffee")

    result = TransactionBatchCategoryUpdater.new.update_category(transactions: [ lunch, coffee ], category: new_category)

    assert_predicate result, :updated?
    assert_equal new_category, lunch.reload.transaction_category
    assert_equal new_category, coffee.reload.transaction_category
  end

  test "rejects category type mismatch without partial updates" do
    user = create(:user)
    account = create_account(user: user)
    old_category = create_category(user: user, name: "Food", category_type: :expense)
    income_category = create_category(user: user, name: "Salary", category_type: :income)
    lunch = create_transaction(user: user, account: account, category: old_category, comment: "Lunch")
    coffee = create_transaction(user: user, account: account, category: old_category, comment: "Coffee")

    result = TransactionBatchCategoryUpdater.new.update_category(transactions: [ lunch, coffee ], category: income_category)

    refute_predicate result, :updated?
    assert_includes result.transaction.errors[:transaction_category], "does not match transaction type"
    assert_equal old_category, lunch.reload.transaction_category
    assert_equal old_category, coffee.reload.transaction_category
  end

  private

  def create_account(user:)
    Account.create!(
      user: user,
      name: "Checking",
      account_category: :checking_account,
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

  def create_transaction(user:, account:, category:, comment:)
    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1_250,
      destination_amount_cents: 0,
      comment: comment
    )
  end
end
