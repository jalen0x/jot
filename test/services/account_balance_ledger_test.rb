require "test_helper"

class AccountBalanceLedgerTest < ActiveSupport::TestCase
  test "apply on income credits the source account" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 1_000)
    transaction = create_transaction(user: user, account: account, transaction_kind: :income, source_amount_cents: 500)

    AccountBalanceLedger.new.apply(transaction)

    assert_equal 1_500, account.reload.balance_cents
  end

  test "apply on expense debits the source account" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 1_000)
    transaction = create_transaction(user: user, account: account, transaction_kind: :expense, source_amount_cents: 300)

    AccountBalanceLedger.new.apply(transaction)

    assert_equal 700, account.reload.balance_cents
  end

  test "apply on balance_adjustment credits the source account" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 1_000)
    transaction = create_transaction(user: user, account: account, transaction_kind: :balance_adjustment, source_amount_cents: 200)

    AccountBalanceLedger.new.apply(transaction)

    assert_equal 1_200, account.reload.balance_cents
  end

  test "apply on transfer debits source and credits destination" do
    user = create(:user)
    source = create_account(user: user, name: "Checking", balance_cents: 5_000)
    destination = create_account(user: user, name: "Savings", balance_cents: 100)
    transaction = create_transaction(
      user: user,
      account: source,
      destination_account: destination,
      transaction_kind: :transfer,
      source_amount_cents: 1_000,
      destination_amount_cents: 1_000
    )

    AccountBalanceLedger.new.apply(transaction)

    assert_equal 4_000, source.reload.balance_cents
    assert_equal 1_100, destination.reload.balance_cents
  end

  test "reverse undoes apply for transfers" do
    user = create(:user)
    source = create_account(user: user, name: "Checking", balance_cents: 5_000)
    destination = create_account(user: user, name: "Savings", balance_cents: 100)
    transaction = create_transaction(
      user: user,
      account: source,
      destination_account: destination,
      transaction_kind: :transfer,
      source_amount_cents: 1_000,
      destination_amount_cents: 1_000
    )

    ledger = AccountBalanceLedger.new
    ledger.apply(transaction)
    ledger.reverse(transaction)

    assert_equal 5_000, source.reload.balance_cents
    assert_equal 100, destination.reload.balance_cents
  end

  test "adjust with zero delta is a no-op" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 1_000)

    AccountBalanceLedger.new.adjust(account, 0)

    assert_equal 1_000, account.reload.balance_cents
  end

  test "adjust survives a stale in-memory balance via atomic SQL increment" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 1_000)

    Account.update_counters(account.id, balance_cents: 200, touch: true)

    AccountBalanceLedger.new.adjust(account, 50)

    assert_equal 1_250, account.reload.balance_cents
  end

  private

  def create_transaction(user:, account:, transaction_kind:, source_amount_cents:, destination_account: nil, destination_amount_cents: 0)
    category =
      if transaction_kind == :balance_adjustment
        nil
      else
        create_category(user: user, category_type: transaction_kind)
      end

    Transaction.create!(
      user: user,
      account: account,
      destination_account: destination_account,
      transaction_category: category,
      transaction_kind: transaction_kind,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: destination_amount_cents
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
