require "test_helper"

class TransactionBatchAccountUpdaterTest < ActiveSupport::TestCase
  test "moves source accounts and reapplies balances" do
    user = create(:user)
    old_account = create_account(user: user, name: "Checking", balance_cents: 3_250)
    new_account = create_account(user: user, name: "Savings", balance_cents: 10_000)
    category = create_category(user: user, name: "Food", category_type: :expense)
    lunch = create_transaction(user: user, account: old_account, category: category, transaction_kind: :expense, source_amount_cents: 1_250, comment: "Lunch")
    coffee = create_transaction(user: user, account: old_account, category: category, transaction_kind: :expense, source_amount_cents: 500, comment: "Coffee")

    result = TransactionBatchAccountUpdater.new.update_account(transactions: [ lunch, coffee ], account: new_account)

    assert_predicate result, :updated?
    assert_equal new_account, lunch.reload.account
    assert_equal new_account, coffee.reload.account
    assert_equal 5_000, old_account.reload.balance_cents
    assert_equal 8_250, new_account.reload.balance_cents
  end

  test "moves transfer destination accounts and reapplies balances" do
    user = create(:user)
    source = create_account(user: user, name: "Checking", balance_cents: 8_000)
    old_destination = create_account(user: user, name: "Savings", balance_cents: 7_000)
    new_destination = create_account(user: user, name: "Brokerage", balance_cents: 1_000)
    category = create_category(user: user, name: "Move", category_type: :transfer)
    transfer = create_transaction(user: user, account: source, destination_account: old_destination, category: category, transaction_kind: :transfer, source_amount_cents: 2_000, destination_amount_cents: 2_000, comment: "Move")

    result = TransactionBatchAccountUpdater.new.update_account(transactions: [ transfer ], account: new_destination, destination_account: true)

    assert_predicate result, :updated?
    assert_equal new_destination, transfer.reload.destination_account
    assert_equal 8_000, source.reload.balance_cents
    assert_equal 5_000, old_destination.reload.balance_cents
    assert_equal 3_000, new_destination.reload.balance_cents
  end

  test "rejects destination account updates for non-transfer transactions without partial updates" do
    user = create(:user)
    old_account = create_account(user: user, name: "Checking", balance_cents: 3_750)
    new_account = create_account(user: user, name: "Savings", balance_cents: 10_000)
    category = create_category(user: user, name: "Food", category_type: :expense)
    expense = create_transaction(user: user, account: old_account, category: category, transaction_kind: :expense, source_amount_cents: 1_250, comment: "Lunch")

    result = TransactionBatchAccountUpdater.new.update_account(transactions: [ expense ], account: new_account, destination_account: true)

    refute_predicate result, :updated?
    assert_includes result.transaction.errors[:destination_account], "can only be updated for transfers"
    assert_equal old_account, expense.reload.account
    assert_equal 3_750, old_account.reload.balance_cents
    assert_equal 10_000, new_account.reload.balance_cents
  end

  test "rejects updates outside the user's transaction edit scope" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD", transaction_edit_scope: "today_or_later")
    old_account = create_account(user: user, name: "Checking", balance_cents: 3_750)
    new_account = create_account(user: user, name: "Savings", balance_cents: 10_000)
    category = create_category(user: user, name: "Food", category_type: :expense)
    expense = create_transaction(user: user, account: old_account, category: category, transaction_kind: :expense, source_amount_cents: 1_250, comment: "Lunch")

    travel_to Time.zone.parse("2026-05-04 12:00:00") do
      result = TransactionBatchAccountUpdater.new.update_account(transactions: [ expense ], account: new_account)

      refute_predicate result, :updated?
      assert_includes result.transaction.errors[:base], "Transaction is outside the editable date range"
    end
    assert_equal old_account, expense.reload.account
    assert_equal 3_750, old_account.reload.balance_cents
    assert_equal 10_000, new_account.reload.balance_cents
  end

  private

  def create_account(user:, name:, balance_cents:, currency_code: "USD")
    Account.create!(
      user: user,
      name: name,
      account_category: :checking_account,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: currency_code,
      balance_cents: balance_cents,
      display_order: 1
    )
  end

  def create_category(user:, name:, category_type:)
    TransactionCategory.create!(user: user, name: name, category_type: category_type, icon_key: 1, color_hex: "F97316", display_order: 1)
  end

  def create_transaction(user:, account:, category:, transaction_kind:, source_amount_cents:, comment:, destination_account: nil, destination_amount_cents: 0)
    Transaction.create!(
      user: user,
      account: account,
      destination_account: destination_account,
      transaction_category: category,
      transaction_kind: transaction_kind,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: destination_amount_cents,
      comment: comment
    )
  end
end
