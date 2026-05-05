require "test_helper"

class TransactionAmountSummaryTest < ActiveSupport::TestCase
  test "summarizes income and expense cents by account currency" do
    user = create(:user)
    other_user = create(:user)
    checking = create_account(user: user, name: "Checking", currency_code: "USD")
    savings = create_account(user: user, name: "Savings", currency_code: "USD")
    cash = create_account(user: user, name: "Cash", currency_code: "CNY")
    range = Time.zone.parse("2026-05-01 00:00:00")..Time.zone.parse("2026-05-31 23:59:59")

    create_transaction(user: user, account: checking, transaction_kind: :income, source_amount_cents: 5_000, transacted_at: Time.zone.parse("2026-05-03 09:00:00"))
    create_transaction(user: user, account: savings, transaction_kind: :income, source_amount_cents: 200, transacted_at: Time.zone.parse("2026-05-03 10:00:00"))
    create_transaction(user: user, account: checking, transaction_kind: :expense, source_amount_cents: 1_200, transacted_at: Time.zone.parse("2026-05-04 09:00:00"))
    create_transaction(user: user, account: cash, transaction_kind: :income, source_amount_cents: 700, transacted_at: Time.zone.parse("2026-05-05 09:00:00"))
    create_transaction(user: user, account: cash, transaction_kind: :expense, source_amount_cents: 300, transacted_at: Time.zone.parse("2026-05-06 09:00:00"))
    create_transaction(user: user, account: checking, destination_account: savings, transaction_kind: :transfer, source_amount_cents: 2_000, destination_amount_cents: 2_000, transacted_at: Time.zone.parse("2026-05-07 09:00:00"))
    create_transaction(user: user, account: checking, transaction_kind: :balance_adjustment, source_amount_cents: 9_999, transacted_at: Time.zone.parse("2026-05-08 09:00:00"))
    create_transaction(user: user, account: checking, transaction_kind: :income, source_amount_cents: 9_999, transacted_at: Time.zone.parse("2026-06-01 09:00:00"))
    discarded = create_transaction(user: user, account: checking, transaction_kind: :income, source_amount_cents: 8_888, transacted_at: Time.zone.parse("2026-05-09 09:00:00"))
    discarded.discard!
    create_transaction(user: other_user, account: create_account(user: other_user, name: "Other", currency_code: "USD"), transaction_kind: :income, source_amount_cents: 7_777, transacted_at: Time.zone.parse("2026-05-03 09:00:00"))

    summary = TransactionAmountSummary.new.summarize_transactions(user: user, range: range)

    assert_equal range, summary.range
    assert_equal [ "CNY", "USD" ], summary.amounts.map(&:currency_code)
    assert_amount summary.amounts.first, currency_code: "CNY", income_cents: 700, expense_cents: 300, net_cents: 400
    assert_amount summary.amounts.second, currency_code: "USD", income_cents: 5_200, expense_cents: 1_200, net_cents: 4_000
  end

  test "summarizes only transactions matching ledger filters" do
    user = create(:user)
    checking = create_account(user: user, name: "Checking", currency_code: "USD")
    savings = create_account(user: user, name: "Savings", currency_code: "USD")
    range = Time.zone.parse("2026-05-01 00:00:00")..Time.zone.parse("2026-05-31 23:59:59")

    create_transaction(user: user, account: checking, transaction_kind: :income, source_amount_cents: 5_000, transacted_at: Time.zone.parse("2026-05-03 09:00:00"), comment: "Client invoice")
    create_transaction(user: user, account: savings, transaction_kind: :income, source_amount_cents: 200, transacted_at: Time.zone.parse("2026-05-03 10:00:00"), comment: "Client invoice")
    create_transaction(user: user, account: checking, transaction_kind: :expense, source_amount_cents: 1_200, transacted_at: Time.zone.parse("2026-05-04 09:00:00"), comment: "Personal lunch")

    summary = TransactionAmountSummary.new.summarize_transactions(
      user: user,
      range: range,
      filters: { account_ids: [ checking.to_param ], keyword: "client" }
    )

    assert_equal [ "USD" ], summary.amounts.map(&:currency_code)
    assert_amount summary.amounts.first, currency_code: "USD", income_cents: 5_000, expense_cents: 0, net_cents: 5_000
  end

  private

  def assert_amount(amount, currency_code:, income_cents:, expense_cents:, net_cents:)
    assert_equal currency_code, amount.currency_code
    assert_equal income_cents, amount.income_cents
    assert_equal expense_cents, amount.expense_cents
    assert_equal net_cents, amount.net_cents
  end

  def create_account(user:, name:, currency_code:)
    Account.create!(
      user: user,
      name: name,
      account_category: :checking_account,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: currency_code,
      balance_cents: 0,
      display_order: 1
    )
  end

  def create_transaction(user:, account:, transaction_kind:, source_amount_cents:, transacted_at:, destination_account: nil, destination_amount_cents: 0, comment: transaction_kind.to_s.humanize)
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
      comment: comment
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
