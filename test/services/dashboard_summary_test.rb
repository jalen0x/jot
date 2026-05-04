require "test_helper"

class DashboardSummaryTest < ActiveSupport::TestCase
  test "summarizes only the current user's kept ledger" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking", balance_cents: 5_000)
    create_account(user: user, name: "Savings", balance_cents: -1_000)
    create_account(user: user, name: "Wallet", balance_cents: 700, currency_code: "CNY")
    discarded_account = create_account(user: user, name: "Closed", balance_cents: 9_999)
    discarded_account.discard!
    create_account(user: other_user, name: "Other", balance_cents: 7_777)
    create_transaction(user: user, account: account, comment: "Groceries")
    discarded_transaction = create_transaction(user: user, account: account, comment: "Discarded")
    discarded_transaction.discard!
    create_transaction(user: other_user, comment: "Other")

    summary = DashboardSummary.new.summarize(user: user)

    assert_respond_to summary, :account_balances
    assert_equal [
      { currency_code: "CNY", balance_cents: 700 },
      { currency_code: "USD", balance_cents: 4_000 }
    ], summary.account_balances.map { |balance| { currency_code: balance.currency_code, balance_cents: balance.balance_cents } }
    assert_equal 3, summary.account_count
    assert_equal 1, summary.transaction_count
    assert_equal [ "Groceries" ], summary.recent_transactions.map(&:comment)
  end

  test "returns five most recent transactions newest first" do
    user = create(:user)
    6.times do |index|
      create_transaction(
        user: user,
        comment: "Transaction #{index}",
        transacted_at: Time.zone.parse("2026-05-0#{index + 1} 10:00:00")
      )
    end

    summary = DashboardSummary.new.summarize(user: user)

    assert_equal [ "Transaction 5", "Transaction 4", "Transaction 3", "Transaction 2", "Transaction 1" ], summary.recent_transactions.map(&:comment)
  end

  private

  def create_account(user:, name:, balance_cents:, currency_code: "USD")
    Account.create!(
      user: user,
      name: name,
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: currency_code,
      balance_cents: balance_cents,
      display_order: 1
    )
  end

  def create_transaction(user:, comment:, transacted_at: Time.zone.parse("2026-05-03 10:00:00"), account: nil)
    account ||= create_account(user: user, name: "Cash #{comment}", balance_cents: 0)
    category = TransactionCategory.create!(
      user: user,
      name: "Food #{comment}",
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: transacted_at,
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1000,
      destination_amount_cents: 0,
      comment: comment
    )
  end
end
