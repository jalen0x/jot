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

  private

  def create_transaction(user:, transaction_kind:, amount_cents:, transacted_at: Time.zone.parse("2026-05-03 10:00:00"), category: nil)
    category ||= create_category(user: user, name: transaction_kind.to_s.humanize, category_type: transaction_kind)
    account = create_account(user: user)

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

  def create_account(user:, name: "Cash")
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
end
