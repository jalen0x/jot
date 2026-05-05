require "test_helper"

class TransactionBatchTagAdderTest < ActiveSupport::TestCase
  test "adds tags to multiple transactions without duplicating existing taggings" do
    user = create(:user)
    account = create_account(user: user)
    category = create_category(user: user)
    existing_tag = create_tag(user: user, name: "Meals")
    new_tag = create_tag(user: user, name: "Business")
    lunch = create_transaction(user: user, account: account, category: category, comment: "Lunch", tags: [ existing_tag ])
    coffee = create_transaction(user: user, account: account, category: category, comment: "Coffee")

    result = TransactionBatchTagAdder.new.add_tags(transactions: [ lunch, coffee ], tags: [ existing_tag, new_tag ])

    assert_predicate result, :added?
    assert_equal [ existing_tag, new_tag ], lunch.reload.transaction_tags.order(:id).to_a
    assert_equal [ existing_tag, new_tag ], coffee.reload.transaction_tags.order(:id).to_a
    assert_equal 4, TransactionTagging.where(transaction_tag: [ existing_tag, new_tag ]).count
  end

  test "rejects additions outside the user's transaction edit scope" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD", transaction_edit_scope: "today_or_later")
    account = create_account(user: user)
    category = create_category(user: user)
    tag = create_tag(user: user, name: "Meals")
    transaction = create_transaction(user: user, account: account, category: category, comment: "Lunch")

    travel_to Time.zone.parse("2026-05-04 12:00:00") do
      result = TransactionBatchTagAdder.new.add_tags(transactions: [ transaction ], tags: [ tag ])

      refute_predicate result, :added?
      assert_includes result.transaction.errors[:base], "Transaction is outside the editable date range"
    end
    assert_empty transaction.reload.transaction_tags
  end

  private

  def create_account(user:)
    Account.create!(
      user: user,
      name: "Checking",
      account_category: :checking_account,
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
      name: "Food",
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end

  def create_tag(user:, name:)
    TransactionTag.create!(user: user, name: name, display_order: 1)
  end

  def create_transaction(user:, account:, category:, comment:, tags: [])
    transaction = Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1_250,
      destination_amount_cents: 0,
      comment: comment
    )
    tags.each { |tag| TransactionTagging.create!(user: user, ledger_transaction: transaction, transaction_tag: tag) }
    transaction
  end
end
