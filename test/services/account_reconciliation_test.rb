require "test_helper"

class AccountReconciliationTest < ActiveSupport::TestCase
  test "builds an account statement for the selected range" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    range = Time.zone.parse("2026-05-03 00:00:00")..Time.zone.parse("2026-05-03 23:59:59")
    create_transaction(
      user: user,
      account: account,
      transaction_kind: :balance_adjustment,
      source_amount_cents: 5_000,
      transacted_at: Time.zone.parse("2026-05-01 09:00:00")
    )
    income = create_transaction(
      user: user,
      account: account,
      transaction_kind: :income,
      source_amount_cents: 2_000,
      transacted_at: Time.zone.parse("2026-05-03 09:00:00")
    )
    expense = create_transaction(
      user: user,
      account: account,
      transaction_kind: :expense,
      source_amount_cents: 1_200,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00")
    )
    create_transaction(
      user: user,
      account: account,
      transaction_kind: :income,
      source_amount_cents: 9_999,
      transacted_at: Time.zone.parse("2026-05-04 09:00:00")
    )
    discarded = create_transaction(
      user: user,
      account: account,
      transaction_kind: :expense,
      source_amount_cents: 777,
      transacted_at: Time.zone.parse("2026-05-03 11:00:00")
    )
    discarded.discard!

    statement = AccountReconciliation.new.build_statement(account: account, range: range)

    assert_equal account, statement.account
    assert_equal range, statement.range
    assert_equal 5_000, statement.opening_balance_cents
    assert_equal 2_000, statement.inflow_cents
    assert_equal 1_200, statement.outflow_cents
    assert_equal 5_800, statement.closing_balance_cents
    assert_equal [ income, expense ], statement.transactions
  end

  test "treats transfers as source outflow and destination inflow" do
    user = create(:user)
    source = create_account(user: user, name: "Checking")
    destination = create_account(user: user, name: "Savings")
    range = Time.zone.parse("2026-05-03 00:00:00")..Time.zone.parse("2026-05-03 23:59:59")
    transfer = create_transaction(
      user: user,
      account: source,
      destination_account: destination,
      transaction_kind: :transfer,
      source_amount_cents: 2_000,
      destination_amount_cents: 2_000,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00")
    )

    source_statement = AccountReconciliation.new.build_statement(account: source, range: range)
    destination_statement = AccountReconciliation.new.build_statement(account: destination, range: range)

    assert_equal [ transfer ], source_statement.transactions
    assert_equal 0, source_statement.inflow_cents
    assert_equal 2_000, source_statement.outflow_cents
    assert_equal(-2_000, source_statement.closing_balance_cents)

    assert_equal [ transfer ], destination_statement.transactions
    assert_equal 2_000, destination_statement.inflow_cents
    assert_equal 0, destination_statement.outflow_cents
    assert_equal 2_000, destination_statement.closing_balance_cents
  end

  test "uses the account owner scope" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking")
    other_account = create_account(user: other_user, name: "Other Checking")
    range = Time.zone.parse("2026-05-03 00:00:00")..Time.zone.parse("2026-05-03 23:59:59")
    create_transaction(
      user: other_user,
      account: other_account,
      transaction_kind: :income,
      source_amount_cents: 9_999,
      transacted_at: Time.zone.parse("2026-05-03 09:00:00")
    )

    statement = AccountReconciliation.new.build_statement(account: account, range: range)

    assert_equal 0, statement.opening_balance_cents
    assert_equal 0, statement.inflow_cents
    assert_equal 0, statement.outflow_cents
    assert_equal 0, statement.closing_balance_cents
    assert_empty statement.transactions
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

  def create_transaction(user:, account:, transaction_kind:, source_amount_cents:, transacted_at:, destination_account: nil, destination_amount_cents: 0)
    Transaction.create!(
      user: user,
      account: account,
      destination_account: destination_account,
      transaction_category: category_for(user, transaction_kind),
      transaction_kind: transaction_kind,
      transacted_at: transacted_at,
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: destination_amount_cents,
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
