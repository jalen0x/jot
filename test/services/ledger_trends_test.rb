require "test_helper"

class LedgerTrendsTest < ActiveSupport::TestCase
  test "builds daily income expense and net buckets" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    range = Time.zone.parse("2026-05-01 00:00:00")..Time.zone.parse("2026-05-03 23:59:59")
    create_transaction(user: user, account: account, transaction_kind: :income, source_amount_cents: 5_000, transacted_at: Time.zone.parse("2026-05-01 09:00:00"))
    create_transaction(user: user, account: account, transaction_kind: :transfer, source_amount_cents: 2_000, destination_amount_cents: 2_000, destination_account: create_account(user: user, name: "Savings"), transacted_at: Time.zone.parse("2026-05-02 09:00:00"))
    create_transaction(user: user, account: account, transaction_kind: :balance_adjustment, source_amount_cents: 9_999, transacted_at: Time.zone.parse("2026-05-02 12:00:00"))
    create_transaction(user: user, account: account, transaction_kind: :expense, source_amount_cents: 1_200, transacted_at: Time.zone.parse("2026-05-03 09:00:00"))
    other_user = create(:user)
    create_transaction(user: other_user, account: create_account(user: other_user, name: "Other Checking"), transaction_kind: :income, source_amount_cents: 8_888, transacted_at: Time.zone.parse("2026-05-01 09:00:00"))

    trends = LedgerTrends.new.build_transaction_trends(user: user, range: range, aggregation: :day, filters: {})

    assert_equal "day", trends.aggregation
    assert_equal range, trends.range
    assert_equal [ Date.new(2026, 5, 1), Date.new(2026, 5, 2), Date.new(2026, 5, 3) ], trends.buckets.map(&:starts_on)
    assert_bucket trends.buckets.first, income_cents: 5_000, expense_cents: 0, net_cents: 5_000
    assert_bucket trends.buckets.second, income_cents: 0, expense_cents: 0, net_cents: 0
    assert_bucket trends.buckets.third, income_cents: 0, expense_cents: 1_200, net_cents: -1_200
  end

  test "builds monthly buckets using existing prefixed id filters" do
    user = create(:user)
    matching_account = create_account(user: user, name: "Checking")
    other_account = create_account(user: user, name: "Savings")
    range = Time.zone.parse("2026-01-01 00:00:00")..Time.zone.parse("2026-02-28 23:59:59")
    create_transaction(user: user, account: matching_account, transaction_kind: :income, source_amount_cents: 1_000, transacted_at: Time.zone.parse("2026-01-15 09:00:00"))
    create_transaction(user: user, account: other_account, transaction_kind: :income, source_amount_cents: 9_999, transacted_at: Time.zone.parse("2026-01-16 09:00:00"))
    create_transaction(user: user, account: matching_account, transaction_kind: :expense, source_amount_cents: 250, transacted_at: Time.zone.parse("2026-02-02 09:00:00"))

    trends = LedgerTrends.new.build_transaction_trends(
      user: user,
      range: range,
      aggregation: "month",
      filters: { account_id: matching_account.to_param }
    )

    assert_equal "month", trends.aggregation
    assert_equal [ Date.new(2026, 1, 1), Date.new(2026, 2, 1) ], trends.buckets.map(&:starts_on)
    assert_bucket trends.buckets.first, income_cents: 1_000, expense_cents: 0, net_cents: 1_000
    assert_bucket trends.buckets.second, income_cents: 0, expense_cents: 250, net_cents: -250
  end

  private

  def assert_bucket(bucket, income_cents:, expense_cents:, net_cents:)
    assert_equal income_cents, bucket.income_cents
    assert_equal expense_cents, bucket.expense_cents
    assert_equal net_cents, bucket.net_cents
  end

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
