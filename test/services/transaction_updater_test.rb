require "test_helper"

class TransactionUpdaterTest < ActiveSupport::TestCase
  test "updates an expense and reapplies balances" do
    user = create(:user)
    old_account = create_account(user: user, name: "Checking", balance_cents: 3_750)
    new_account = create_account(user: user, name: "Savings", balance_cents: 10_000)
    old_category = create_category(user: user, name: "Food", category_type: :expense)
    new_category = create_category(user: user, name: "Travel", category_type: :expense)
    old_tag = create_tag(user: user, name: "Old")
    new_tag = create_tag(user: user, name: "New")
    transaction = create_transaction(
      user: user,
      account: old_account,
      category: old_category,
      transaction_kind: :expense,
      source_amount_cents: 1_250,
      comment: "Lunch",
      tags: [ old_tag ]
    )
    transaction.pictures.attach(io: StringIO.new("receipt"), filename: "receipt.txt", content_type: "text/plain", identify: false)

    result = TransactionUpdater.new.update_transaction(
      transaction: transaction,
      attributes: transaction_attributes(
        transaction_kind: "expense",
        account_id: new_account.to_param,
        transaction_category_id: new_category.to_param,
        source_amount_cents: "2000",
        comment: "Flight",
        geo_location: { latitude: "37.7749", longitude: "-122.4194" }
      ),
      tag_ids: [ new_tag.to_param ]
    )

    assert_predicate result, :updated?
    assert_equal 5_000, old_account.reload.balance_cents
    assert_equal 8_000, new_account.reload.balance_cents
    assert_equal new_account, transaction.reload.account
    assert_equal new_category, transaction.transaction_category
    assert_equal 2_000, transaction.source_amount_cents
    assert_equal "Flight", transaction.comment
    assert_equal BigDecimal("37.7749"), transaction.geo_latitude
    assert_equal BigDecimal("-122.4194"), transaction.geo_longitude
    assert_equal [ new_tag ], transaction.transaction_tags.to_a
    assert_predicate transaction.pictures, :attached?
  end

  test "updates a transfer and reapplies both account balances" do
    user = create(:user)
    source = create_account(user: user, name: "Checking", balance_cents: 8_000)
    destination = create_account(user: user, name: "Savings", balance_cents: 7_000)
    category = create_category(user: user, name: "Move", category_type: :transfer)
    transaction = create_transaction(
      user: user,
      account: source,
      destination_account: destination,
      category: category,
      transaction_kind: :transfer,
      source_amount_cents: 2_000,
      destination_amount_cents: 2_000,
      comment: "Old transfer"
    )

    result = TransactionUpdater.new.update_transaction(
      transaction: transaction,
      attributes: transaction_attributes(
        transaction_kind: "transfer",
        account_id: source.to_param,
        destination_account_id: destination.to_param,
        transaction_category_id: category.to_param,
        source_amount_cents: "1500",
        destination_amount_cents: "1500",
        comment: "New transfer"
      ),
      tag_ids: []
    )

    assert_predicate result, :updated?
    assert_equal 8_500, source.reload.balance_cents
    assert_equal 6_500, destination.reload.balance_cents
    assert_equal 1_500, transaction.reload.source_amount_cents
    assert_equal 1_500, transaction.destination_amount_cents
  end

  test "rejects unavailable owned records without changing balances" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking", balance_cents: 3_750)
    category = create_category(user: user, name: "Food", category_type: :expense)
    old_tag = create_tag(user: user, name: "Old")
    other_account = create_account(user: other_user, name: "Other", balance_cents: 9_000)
    other_category = create_category(user: other_user, name: "Other Food", category_type: :expense)
    other_tag = create_tag(user: other_user, name: "Other Tag")
    transaction = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      source_amount_cents: 1_250,
      comment: "Lunch",
      tags: [ old_tag ]
    )

    result = TransactionUpdater.new.update_transaction(
      transaction: transaction,
      attributes: transaction_attributes(
        account_id: other_account.to_param,
        transaction_category_id: other_category.to_param,
        source_amount_cents: "2000"
      ),
      tag_ids: [ other_tag.to_param ]
    )

    refute_predicate result, :updated?
    assert_includes transaction.errors[:account], "is unavailable"
    assert_includes transaction.errors[:transaction_category], "is unavailable"
    assert_includes transaction.errors[:transaction_tags], "include unavailable tags"
    assert_equal 3_750, account.reload.balance_cents
    assert_equal 9_000, other_account.reload.balance_cents
    assert_equal old_tag, transaction.reload.transaction_tags.sole
    assert_equal 1_250, transaction.source_amount_cents
  end

  private

  def transaction_attributes(overrides)
    {
      transaction_kind: "expense",
      transacted_at: "2026-05-03 10:00:00",
      timezone_utc_offset_minutes: "0",
      source_amount_cents: "1000",
      destination_amount_cents: "0",
      hide_amount: "0",
      comment: "Updated from Rails"
    }.merge(overrides)
  end

  def create_account(user:, name:, balance_cents: 0, currency_code: "USD")
    Account.create!(
      user: user,
      name: name,
      account_category: :checking_account,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: currency_code,
      balance_cents: balance_cents,
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

  def create_tag(user:, name:)
    TransactionTag.create!(user: user, name: name, display_order: 1)
  end

  def create_transaction(user:, account:, category:, transaction_kind:, source_amount_cents:, comment:, tags: [], destination_account: nil, destination_amount_cents: 0)
    transaction = Transaction.create!(
      user: user,
      account: account,
      destination_account: destination_account,
      transaction_category: category,
      transaction_kind: transaction_kind,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: destination_amount_cents,
      comment: comment
    )
    tags.each { |tag| TransactionTagging.create!(user: user, ledger_transaction: transaction, transaction_tag: tag) }
    transaction
  end
end
