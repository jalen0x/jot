require "test_helper"

class LedgerStatisticsTest < ActiveSupport::TestCase
  test "summarizes income expense net and category totals for current user and date range" do
    user = create(:user)
    other_user = create(:user)
    salary = create_category(user: user, name: "Salary", category_type: :income)
    food = create_category(user: user, name: "Food", category_type: :expense)
    create_transaction(user: user, category: salary, transaction_kind: :income, amount_cents: 5_000, transacted_at: Time.zone.parse("2026-05-03 09:00:00"))
    create_transaction(user: user, category: food, transaction_kind: :expense, amount_cents: 1_200, transacted_at: Time.zone.parse("2026-05-03 10:00:00"))
    create_transaction(user: user, category: food, transaction_kind: :expense, amount_cents: 300, transacted_at: Time.zone.parse("2026-05-04 10:00:00"))
    create_transaction(user: user, category: salary, transaction_kind: :income, amount_cents: 9_999, transacted_at: Time.zone.parse("2026-06-01 10:00:00"))
    create_transaction(user: other_user, transaction_kind: :income, amount_cents: 7_777, transacted_at: Time.zone.parse("2026-05-03 10:00:00"))

    summary = LedgerStatistics.new.summarize_transactions(
      user: user,
      range: Time.zone.parse("2026-05-01")..Time.zone.parse("2026-05-31 23:59:59")
    )

    assert_equal 5_000, summary.income_cents
    assert_equal 1_500, summary.expense_cents
    assert_equal 3_500, summary.net_cents
    assert_equal({ "Salary" => 5_000, "Food" => -1_500 }, summary.category_totals.transform_values(&:itself))
  end

  test "summarizes income expense and net by account currency" do
    user = create(:user)
    usd_account = create_account(user: user, name: "Checking", currency_code: "USD")
    cny_account = create_account(user: user, name: "Wallet", currency_code: "CNY")
    salary = create_category(user: user, name: "Salary", category_type: :income)
    food = create_category(user: user, name: "Food", category_type: :expense)
    create_transaction(user: user, account: usd_account, category: salary, transaction_kind: :income, amount_cents: 5_000)
    create_transaction(user: user, account: usd_account, category: food, transaction_kind: :expense, amount_cents: 1_200)
    create_transaction(user: user, account: cny_account, category: salary, transaction_kind: :income, amount_cents: 700)

    summary = LedgerStatistics.new.summarize_transactions(user: user, range: Time.zone.parse("2026-05-01")..Time.zone.parse("2026-05-31 23:59:59"))

    assert_respond_to summary, :amounts
    assert_equal [
      { currency_code: "CNY", income_cents: 700, expense_cents: 0, net_cents: 700 },
      { currency_code: "USD", income_cents: 5_000, expense_cents: 1_200, net_cents: 3_800 }
    ], summary.amounts.map { |amount| { currency_code: amount.currency_code, income_cents: amount.income_cents, expense_cents: amount.expense_cents, net_cents: amount.net_cents } }
  end

  test "ignores transfers and discarded transactions" do
    user = create(:user)
    income_category = create_category(user: user, name: "Salary", category_type: :income)
    transfer_category = create_category(user: user, name: "Transfer", category_type: :transfer)
    discarded = create_transaction(user: user, category: income_category, transaction_kind: :income, amount_cents: 5_000)
    discarded.discard!
    create_transfer(user: user, category: transfer_category, amount_cents: 2_000)

    summary = LedgerStatistics.new.summarize_transactions(user: user, range: Time.zone.parse("2026-05-01")..Time.zone.parse("2026-05-31 23:59:59"))

    assert_equal 0, summary.income_cents
    assert_equal 0, summary.expense_cents
    assert_empty summary.category_totals
  end

  test "returns signed account totals" do
    user = create(:user)
    checking = create_account(user: user, name: "Checking")
    savings = create_account(user: user, name: "Savings")
    salary = create_category(user: user, name: "Salary", category_type: :income)
    food = create_category(user: user, name: "Food", category_type: :expense)
    create_transaction(user: user, account: checking, category: salary, transaction_kind: :income, amount_cents: 5_000)
    create_transaction(user: user, account: checking, category: food, transaction_kind: :expense, amount_cents: 1_200)
    create_transaction(user: user, account: savings, category: food, transaction_kind: :expense, amount_cents: 300)

    summary = LedgerStatistics.new.summarize_transactions(user: user, range: Time.zone.parse("2026-05-01")..Time.zone.parse("2026-05-31 23:59:59"))

    assert_equal({ "Checking" => 3_800, "Savings" => -300 }, summary.account_totals.transform_values(&:itself))
  end

  test "applies existing ledger filters" do
    user = create(:user)
    matching_account = create_account(user: user, name: "Checking")
    other_account = create_account(user: user, name: "Savings")
    salary = create_category(user: user, name: "Salary", category_type: :income)
    create_transaction(user: user, account: matching_account, category: salary, transaction_kind: :income, amount_cents: 5_000)
    create_transaction(user: user, account: other_account, category: salary, transaction_kind: :income, amount_cents: 9_999)

    summary = LedgerStatistics.new.summarize_transactions(
      user: user,
      range: Time.zone.parse("2026-05-01")..Time.zone.parse("2026-05-31 23:59:59"),
      filters: { account_id: matching_account.to_param }
    )

    assert_equal 5_000, summary.income_cents
    assert_equal({ "Salary" => 5_000 }, summary.category_totals.transform_values(&:itself))
    assert_equal({ "Checking" => 5_000 }, summary.account_totals.transform_values(&:itself))
  end

  private

  def create_transaction(user:, transaction_kind:, amount_cents:, transacted_at: Time.zone.parse("2026-05-03 10:00:00"), category: nil, account: nil)
    category ||= create_category(user: user, name: transaction_kind.to_s.humanize, category_type: transaction_kind)
    account ||= create_account(user: user)

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: transaction_kind,
      transacted_at: transacted_at,
      timezone_utc_offset_minutes: 0,
      source_amount_cents: amount_cents,
      destination_amount_cents: 0
    )
  end

  def create_transfer(user:, category:, amount_cents:)
    Transaction.create!(
      user: user,
      account: create_account(user: user, name: "Checking"),
      destination_account: create_account(user: user, name: "Savings"),
      transaction_category: category,
      transaction_kind: :transfer,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: amount_cents,
      destination_amount_cents: amount_cents
    )
  end

  def create_account(user:, name: "Cash", currency_code: "USD")
    Account.create!(
      user: user,
      name: name,
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
