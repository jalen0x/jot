require "test_helper"

class TransactionAccountMoverTest < ActiveSupport::TestCase
  test "moves every kept source and destination account appearance and reapplies balances" do
    user = create(:user)
    from_account = create_account(user: user, name: "Checking", balance_cents: 10_000)
    to_account = create_account(user: user, name: "Savings", balance_cents: 1_000)
    other_account = create_account(user: user, name: "Brokerage", balance_cents: 50_000)
    income_category = create_category(user: user, name: "Salary", category_type: :income)
    expense_category = create_category(user: user, name: "Food", category_type: :expense)
    transfer_category = create_category(user: user, name: "Move", category_type: :transfer)
    income = create_transaction(user: user, account: from_account, category: income_category, transaction_kind: :income, source_amount_cents: 3_000, comment: "Paycheck")
    expense = create_transaction(user: user, account: from_account, category: expense_category, transaction_kind: :expense, source_amount_cents: 1_200, comment: "Lunch")
    outgoing_transfer = create_transaction(user: user, account: from_account, destination_account: other_account, category: transfer_category, transaction_kind: :transfer, source_amount_cents: 700, destination_amount_cents: 700, comment: "Invest")
    incoming_transfer = create_transaction(user: user, account: other_account, destination_account: from_account, category: transfer_category, transaction_kind: :transfer, source_amount_cents: 2_000, destination_amount_cents: 2_000, comment: "Refund")
    decoy = create_transaction(user: user, account: other_account, category: expense_category, transaction_kind: :expense, source_amount_cents: 500, comment: "Decoy")
    discarded = create_transaction(user: user, account: from_account, category: expense_category, transaction_kind: :expense, source_amount_cents: 900, comment: "Archived")
    discarded.discard!

    result = TransactionAccountMover.new.move_between_accounts(user: user, from_account: from_account, to_account: to_account)

    assert_predicate result, :moved?
    assert_equal to_account, income.reload.account
    assert_equal to_account, expense.reload.account
    assert_equal to_account, outgoing_transfer.reload.account
    assert_equal other_account, outgoing_transfer.destination_account
    assert_equal other_account, incoming_transfer.reload.account
    assert_equal to_account, incoming_transfer.destination_account
    assert_equal other_account, decoy.reload.account
    assert_equal from_account, discarded.reload.account
    assert_equal 6_900, from_account.reload.balance_cents
    assert_equal 4_100, to_account.reload.balance_cents
    assert_equal 50_000, other_account.reload.balance_cents
  end

  test "rejects moves that would make a transfer use the same source and destination account" do
    user = create(:user)
    from_account = create_account(user: user, name: "Checking", balance_cents: 8_000)
    to_account = create_account(user: user, name: "Savings", balance_cents: 3_000)
    category = create_category(user: user, name: "Move", category_type: :transfer)
    transfer = create_transaction(user: user, account: from_account, destination_account: to_account, category: category, transaction_kind: :transfer, source_amount_cents: 2_000, destination_amount_cents: 2_000, comment: "Move")

    result = TransactionAccountMover.new.move_between_accounts(user: user, from_account: from_account, to_account: to_account)

    refute_predicate result, :moved?
    assert_includes result.errors, "Move would make a transfer use the same source and destination account"
    assert_equal from_account, transfer.reload.account
    assert_equal to_account, transfer.destination_account
    assert_equal 8_000, from_account.reload.balance_cents
    assert_equal 3_000, to_account.reload.balance_cents
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
      transacted_at: Time.zone.parse("2026-05-04 12:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: destination_amount_cents,
      comment: comment
    )
  end
end
