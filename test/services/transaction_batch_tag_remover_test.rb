require "test_helper"

class TransactionBatchTagRemoverTest < ActiveSupport::TestCase
  test "removes requested tags from multiple transactions only" do
    user = create(:user)
    account = create_account(user: user)
    category = create_category(user: user)
    meals_tag = create_tag(user: user, name: "Meals")
    business_tag = create_tag(user: user, name: "Business")
    personal_tag = create_tag(user: user, name: "Personal")
    lunch = create_transaction(user: user, account: account, category: category, comment: "Lunch", tags: [ meals_tag, business_tag, personal_tag ])
    coffee = create_transaction(user: user, account: account, category: category, comment: "Coffee", tags: [ meals_tag, personal_tag ])
    decoy = create_transaction(user: user, account: account, category: category, comment: "Decoy", tags: [ meals_tag ])

    result = TransactionBatchTagRemover.new.remove_tags(transactions: [ lunch, coffee ], tags: [ meals_tag, business_tag ])

    assert_predicate result, :removed?
    assert_equal [ personal_tag ], lunch.reload.transaction_tags.order(:id).to_a
    assert_equal [ personal_tag ], coffee.reload.transaction_tags.order(:id).to_a
    assert_equal [ meals_tag ], decoy.reload.transaction_tags.order(:id).to_a
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
