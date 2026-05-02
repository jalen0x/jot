require "test_helper"

class LedgerQueryTest < ActiveSupport::TestCase
  test "lists current user transactions newest first" do
    user = create(:user)
    other_user = create(:user)
    older = create_transaction(user: user, comment: "Older", transacted_at: Time.zone.parse("2026-05-01 10:00:00"))
    newer = create_transaction(user: user, comment: "Newer", transacted_at: Time.zone.parse("2026-05-02 10:00:00"))
    create_transaction(user: other_user, comment: "Other", transacted_at: Time.zone.parse("2026-05-03 10:00:00"))

    transactions = LedgerQuery.new.list_transactions(user: user, filters: {})

    assert_equal [ newer, older ], transactions.to_a
  end

  test "filters by tag" do
    user = create(:user)
    matching_tag = create_tag(user: user, name: "Business")
    other_tag = create_tag(user: user, name: "Personal")
    matching = create_transaction(user: user, comment: "Matching")
    other = create_transaction(user: user, comment: "Other")
    TransactionTagging.create!(user: user, ledger_transaction: matching, transaction_tag: matching_tag)
    TransactionTagging.create!(user: user, ledger_transaction: other, transaction_tag: other_tag)

    transactions = LedgerQuery.new.list_transactions(user: user, filters: { tag_id: matching_tag.id.to_s })

    assert_equal [ matching ], transactions.to_a
  end

  private

  def create_transaction(user:, comment:, transacted_at: Time.zone.parse("2026-05-03 10:00:00"))
    account = create_account(user: user)
    category = create_category(user: user)

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

  def create_category(user:)
    TransactionCategory.create!(
      user: user,
      name: "Groceries",
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end

  def create_tag(user:, name:)
    TransactionTag.create!(user: user, name: name, display_order: 1)
  end
end
