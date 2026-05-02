require "test_helper"

class TransactionTaggingTest < ActiveSupport::TestCase
  test "joins a transaction and tag for the same user" do
    user = create(:user)
    account = create_account(user: user)
    transaction = create_transaction(user: user, account: account)
    tag = TransactionTag.create!(user: user, name: "Business", display_order: 1)

    tagging = TransactionTagging.create!(user: user, ledger_transaction: transaction, transaction_tag: tag)

    assert_equal transaction, tagging.ledger_transaction
    assert_equal tag, tagging.transaction_tag
  end

  private

  def create_account(user:)
    Account.create!(
      user: user,
      name: "Cash",
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: 0,
      display_order: 1
    )
  end

  def create_transaction(user:, account:)
    Transaction.create!(
      user: user,
      account: account,
      transaction_category: create_category(user: user),
      transaction_kind: :income,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1000,
      destination_amount_cents: 0
    )
  end

  def create_category(user:)
    TransactionCategory.create!(
      user: user,
      name: "Salary",
      category_type: :income,
      icon_key: 1,
      color_hex: "22C55E",
      display_order: 1
    )
  end
end
