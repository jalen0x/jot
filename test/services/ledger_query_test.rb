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

  test "filters by prefixed account id" do
    user = create(:user)
    matching_account = create_account(user: user)
    other_account = create_account(user: user, name: "Savings")
    matching = create_transaction(user: user, comment: "Matching", account: matching_account)
    create_transaction(user: user, comment: "Other", account: other_account)

    transactions = LedgerQuery.new.list_transactions(user: user, filters: { account_id: matching_account.to_param })

    assert_equal [ matching ], transactions.to_a
  end

  test "filters by prefixed transaction category id" do
    user = create(:user)
    matching_category = create_category(user: user, name: "Groceries")
    other_category = create_category(user: user, name: "Travel")
    matching = create_transaction(user: user, comment: "Matching", category: matching_category)
    create_transaction(user: user, comment: "Other", category: other_category)

    transactions = LedgerQuery.new.list_transactions(user: user, filters: { transaction_category_id: matching_category.to_param })

    assert_equal [ matching ], transactions.to_a
  end

  test "filters by prefixed tag id" do
    user = create(:user)
    matching_tag = create_tag(user: user, name: "Business")
    other_tag = create_tag(user: user, name: "Personal")
    matching = create_transaction(user: user, comment: "Matching")
    other = create_transaction(user: user, comment: "Other")
    TransactionTagging.create!(user: user, ledger_transaction: matching, transaction_tag: matching_tag)
    TransactionTagging.create!(user: user, ledger_transaction: other, transaction_tag: other_tag)

    transactions = LedgerQuery.new.list_transactions(user: user, filters: { tag_id: matching_tag.to_param })

    assert_equal [ matching ], transactions.to_a
  end

  test "filters by any selected tags" do
    user = create(:user)
    business_tag = create_tag(user: user, name: "Business")
    travel_tag = create_tag(user: user, name: "Travel")
    personal_tag = create_tag(user: user, name: "Personal")
    business = create_transaction(user: user, comment: "Business", transacted_at: Time.zone.parse("2026-05-03 11:00:00"))
    travel = create_transaction(user: user, comment: "Travel", transacted_at: Time.zone.parse("2026-05-03 10:00:00"))
    create_transaction(user: user, comment: "Personal", transacted_at: Time.zone.parse("2026-05-03 09:00:00")).tap { |transaction| tag(transaction, personal_tag) }
    create_transaction(user: user, comment: "Untagged", transacted_at: Time.zone.parse("2026-05-03 08:00:00"))
    tag(business, business_tag)
    tag(travel, travel_tag)

    transactions = LedgerQuery.new.list_transactions(
      user: user,
      filters: { tag_filter: { include_any_ids: [ business_tag.to_param, travel_tag.to_param ] } }
    )

    assert_equal [ business, travel ], transactions.to_a
  end

  test "filters by all selected tags" do
    user = create(:user)
    business_tag = create_tag(user: user, name: "Business")
    reimbursable_tag = create_tag(user: user, name: "Reimbursable")
    matching = create_transaction(user: user, comment: "Client lunch")
    partial = create_transaction(user: user, comment: "Office coffee")
    tag(matching, business_tag)
    tag(matching, reimbursable_tag)
    tag(partial, business_tag)

    transactions = LedgerQuery.new.list_transactions(
      user: user,
      filters: { tag_filter: { include_all_ids: [ business_tag.to_param, reimbursable_tag.to_param ] } }
    )

    assert_equal [ matching ], transactions.to_a
  end

  test "excludes transactions with any selected tags" do
    user = create(:user)
    business_tag = create_tag(user: user, name: "Business")
    reimbursable_tag = create_tag(user: user, name: "Reimbursable")
    other_tag = create_tag(user: user, name: "Personal")
    tagged_with_other = create_transaction(user: user, comment: "Dinner", transacted_at: Time.zone.parse("2026-05-03 11:00:00"))
    untagged = create_transaction(user: user, comment: "Coffee", transacted_at: Time.zone.parse("2026-05-03 10:00:00"))
    tag(tagged_with_other, other_tag)
    tag(create_transaction(user: user, comment: "Client lunch", transacted_at: Time.zone.parse("2026-05-03 09:00:00")), business_tag)
    tag(create_transaction(user: user, comment: "Taxi", transacted_at: Time.zone.parse("2026-05-03 08:00:00")), reimbursable_tag)

    transactions = LedgerQuery.new.list_transactions(
      user: user,
      filters: { tag_filter: { exclude_any_ids: [ business_tag.to_param, reimbursable_tag.to_param ] } }
    )

    assert_equal [ tagged_with_other, untagged ], transactions.to_a
  end

  test "excludes transactions with all selected tags" do
    user = create(:user)
    business_tag = create_tag(user: user, name: "Business")
    reimbursable_tag = create_tag(user: user, name: "Reimbursable")
    only_business = create_transaction(user: user, comment: "Office coffee", transacted_at: Time.zone.parse("2026-05-03 11:00:00"))
    untagged = create_transaction(user: user, comment: "Snack", transacted_at: Time.zone.parse("2026-05-03 10:00:00"))
    matching_all = create_transaction(user: user, comment: "Client lunch", transacted_at: Time.zone.parse("2026-05-03 09:00:00"))
    tag(only_business, business_tag)
    tag(matching_all, business_tag)
    tag(matching_all, reimbursable_tag)

    transactions = LedgerQuery.new.list_transactions(
      user: user,
      filters: { tag_filter: { exclude_all_ids: [ business_tag.to_param, reimbursable_tag.to_param ] } }
    )

    assert_equal [ only_business, untagged ], transactions.to_a
  end

  test "filters transactions without tags" do
    user = create(:user)
    business_tag = create_tag(user: user, name: "Business")
    untagged = create_transaction(user: user, comment: "Coffee")
    tag(create_transaction(user: user, comment: "Client lunch"), business_tag)

    transactions = LedgerQuery.new.list_transactions(
      user: user,
      filters: { tag_filter: { without_tags: "true" } }
    )

    assert_equal [ untagged ], transactions.to_a
  end

  test "filters by keyword in transaction comments" do
    user = create(:user)
    matching = create_transaction(user: user, comment: "Client lunch")
    create_transaction(user: user, comment: "Family lunch")
    create_transaction(user: create(:user), comment: "Client lunch")

    transactions = LedgerQuery.new.list_transactions(user: user, filters: { keyword: "client" })

    assert_equal [ matching ], transactions.to_a
  end

  private

  def create_transaction(user:, comment:, transacted_at: Time.zone.parse("2026-05-03 10:00:00"), account: nil, category: nil)
    account ||= create_account(user: user)
    category ||= create_category(user: user)

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

  def create_category(user:, name: "Groceries")
    TransactionCategory.create!(
      user: user,
      name: name,
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end

  def create_tag(user:, name:)
    TransactionTag.create!(user: user, name: name, display_order: 1)
  end

  def tag(transaction, transaction_tag)
    TransactionTagging.create!(user: transaction.user, ledger_transaction: transaction, transaction_tag: transaction_tag)
  end
end
