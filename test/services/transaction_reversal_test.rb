require "test_helper"

class TransactionReversalTest < ActiveSupport::TestCase
  test "deletes income and subtracts its amount from the account" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 3_500)
    transaction = create_transaction(user: user, account: account, transaction_kind: :income, source_amount_cents: 2_500)

    result = TransactionReversal.new.delete_transaction(transaction: transaction)

    assert_predicate result, :deleted?
    assert_predicate transaction.reload, :discarded?
    assert_equal 1_000, account.reload.balance_cents
  end

  test "deletes expense and adds its amount back to the account" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 3_800)
    transaction = create_transaction(user: user, account: account, transaction_kind: :expense, source_amount_cents: 1_200)

    result = TransactionReversal.new.delete_transaction(transaction: transaction)

    assert_predicate result, :deleted?
    assert_predicate transaction.reload, :discarded?
    assert_equal 5_000, account.reload.balance_cents
  end

  test "deletes transfer and reverses both account balances" do
    user = create(:user)
    source = create_account(user: user, name: "Checking", balance_cents: 3_000)
    destination = create_account(user: user, name: "Savings", balance_cents: 3_000)
    transaction = create_transaction(
      user: user,
      account: source,
      destination_account: destination,
      transaction_kind: :transfer,
      source_amount_cents: 2_000,
      destination_amount_cents: 2_000,
      category_type: :transfer
    )

    result = TransactionReversal.new.delete_transaction(transaction: transaction)

    assert_predicate result, :deleted?
    assert_predicate transaction.reload, :discarded?
    assert_equal 5_000, source.reload.balance_cents
    assert_equal 1_000, destination.reload.balance_cents
  end

  test "does not reverse an already discarded transaction twice" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 3_500)
    transaction = create_transaction(user: user, account: account, transaction_kind: :income, source_amount_cents: 2_500)
    transaction.discard!

    result = TransactionReversal.new.delete_transaction(transaction: transaction)

    refute_predicate result, :deleted?
    assert_includes result.transaction.errors[:base], "Transaction is already deleted"
    assert_equal 3_500, account.reload.balance_cents
  end

  private

  def create_transaction(user:, account:, transaction_kind:, source_amount_cents:, destination_account: nil, destination_amount_cents: 0, category_type: transaction_kind)
    Transaction.create!(
      user: user,
      account: account,
      destination_account: destination_account,
      transaction_category: create_category(user: user, category_type: category_type),
      transaction_kind: transaction_kind,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: destination_amount_cents,
      comment: "Original"
    )
  end

  def create_account(user:, name: "Cash", balance_cents:)
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
end
