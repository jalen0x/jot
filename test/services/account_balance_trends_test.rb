require "test_helper"

class AccountBalanceTrendsTest < ActiveSupport::TestCase
  test "builds daily opening and closing balances for kept accounts" do
    user = create(:user)
    other_user = create(:user)
    checking = create_account(user: user, name: "Checking", display_order: 1)
    savings = create_account(user: user, name: "Savings", display_order: 2)
    discarded_account = create_account(user: user, name: "Closed", display_order: 3)
    discarded_account.discard!
    range = Time.zone.parse("2026-05-03 00:00:00")..Time.zone.parse("2026-05-04 23:59:59")

    create_transaction(user: user, account: checking, transaction_kind: :balance_adjustment, source_amount_cents: 5_000, transacted_at: Time.zone.parse("2026-05-01 09:00:00"))
    create_transaction(user: user, account: savings, transaction_kind: :balance_adjustment, source_amount_cents: 1_000, transacted_at: Time.zone.parse("2026-05-01 10:00:00"))
    create_transaction(user: user, account: checking, transaction_kind: :income, source_amount_cents: 2_000, transacted_at: Time.zone.parse("2026-05-03 09:00:00"))
    create_transaction(user: user, account: checking, transaction_kind: :expense, source_amount_cents: 1_200, transacted_at: Time.zone.parse("2026-05-03 10:00:00"))
    create_transaction(user: user, account: checking, destination_account: savings, transaction_kind: :transfer, source_amount_cents: 1_500, destination_amount_cents: 1_500, transacted_at: Time.zone.parse("2026-05-03 11:00:00"))
    create_transaction(user: user, account: savings, transaction_kind: :expense, source_amount_cents: 300, transacted_at: Time.zone.parse("2026-05-04 09:00:00"))
    discarded_transaction = create_transaction(user: user, account: checking, transaction_kind: :income, source_amount_cents: 9_999, transacted_at: Time.zone.parse("2026-05-03 12:00:00"))
    discarded_transaction.discard!
    create_transaction(user: user, account: discarded_account, transaction_kind: :income, source_amount_cents: 7_777, transacted_at: Time.zone.parse("2026-05-03 13:00:00"))
    create_transaction(user: other_user, account: create_account(user: other_user, name: "Other Checking", display_order: 1), transaction_kind: :income, source_amount_cents: 8_888, transacted_at: Time.zone.parse("2026-05-03 09:00:00"))

    trends = AccountBalanceTrends.new.build_account_balance_trends(user: user, range: range)

    assert_equal range, trends.range
    assert_equal [ Date.new(2026, 5, 3), Date.new(2026, 5, 4) ], trends.buckets.map(&:starts_on)

    may_3 = trends.buckets.first.account_balances
    assert_equal [ checking, savings ], may_3.map(&:account)
    assert_account_balance may_3.first, opening_balance_cents: 5_000, closing_balance_cents: 4_300
    assert_account_balance may_3.second, opening_balance_cents: 1_000, closing_balance_cents: 2_500

    may_4 = trends.buckets.second.account_balances
    assert_equal [ checking, savings ], may_4.map(&:account)
    assert_account_balance may_4.first, opening_balance_cents: 4_300, closing_balance_cents: 4_300
    assert_account_balance may_4.second, opening_balance_cents: 2_500, closing_balance_cents: 2_200
  end

  private

  def assert_account_balance(account_balance, opening_balance_cents:, closing_balance_cents:)
    assert_equal opening_balance_cents, account_balance.opening_balance_cents
    assert_equal closing_balance_cents, account_balance.closing_balance_cents
  end

  def create_account(user:, name:, display_order:)
    Account.create!(
      user: user,
      name: name,
      account_category: :checking_account,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: 0,
      display_order: display_order
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
