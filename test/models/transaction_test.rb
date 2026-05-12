require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  test "transfer transactions require a destination account" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    destination_account = create_account(user: user, name: "Savings")
    category = create_category(user: user, category_type: :transfer)

    transaction = Transaction.create!(
      user: user,
      account: account,
      destination_account: destination_account,
      transaction_category: category,
      transaction_kind: :transfer,
      transacted_at: Time.zone.parse("2026-05-03 09:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1000,
      destination_amount_cents: 1000
    )

    error = assert_raises(ActiveRecord::StatementInvalid) do
      transaction.update_column(:destination_account_id, nil)
    end

    assert_match(/transactions_transfer_destination_required/i, error.message)
  end

  test "normal transactions require a category" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")

    transaction = Transaction.new(
      user: user,
      account: account,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1500,
      destination_amount_cents: 0
    )

    refute_predicate transaction, :valid?
    assert_includes transaction.errors[:transaction_category], "can't be blank"
  end

  test "database rejects a normal transaction without a category" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, category_type: :expense)

    transaction = Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 11:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1500,
      destination_amount_cents: 0
    )

    error = assert_raises(ActiveRecord::StatementInvalid) do
      transaction.update_column(:transaction_category_id, nil)
    end

    assert_match(/transactions_normal_category_required/i, error.message)
  end

  test "balance adjustments cannot have a category" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, category_type: :expense)

    transaction = Transaction.new(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :balance_adjustment,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1500,
      destination_amount_cents: 0
    )

    refute_predicate transaction, :valid?
    assert_includes transaction.errors[:transaction_category], "must be blank"
  end

  test "location requires latitude and longitude together" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, category_type: :expense)

    transaction = Transaction.new(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-04 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1500,
      destination_amount_cents: 0,
      geo_latitude: 37.7749
    )

    refute_predicate transaction, :valid?
    assert_includes transaction.errors[:geo_longitude], "can't be blank when latitude is present"
  end

  test "database rejects out of range latitude" do
    transaction = create_transaction_with_location(geo_latitude: 37.7749, geo_longitude: -122.4194)

    error = assert_raises(ActiveRecord::StatementInvalid) do
      transaction.update_column(:geo_latitude, 91)
    end

    assert_match(/transactions_geo_latitude_range/i, error.message)
  end

  test "database rejects half locations" do
    transaction = create_transaction_with_location(geo_latitude: 37.7749, geo_longitude: -122.4194)

    error = assert_raises(ActiveRecord::StatementInvalid) do
      transaction.update_column(:geo_longitude, nil)
    end

    assert_match(/transactions_geo_location_pair/i, error.message)
  end

  test "balance_effects on a non-transfer returns one (account, delta) entry" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, category_type: :expense)

    transaction = Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-04 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1500,
      destination_amount_cents: 0
    )

    assert_equal [ [ account, -1500 ] ], transaction.balance_effects
  end

  test "balance_effects on a transfer returns source and destination entries" do
    user = create(:user)
    source = create_account(user: user, name: "Checking")
    destination = create_account(user: user, name: "Savings")
    category = create_category(user: user, category_type: :transfer)

    transaction = Transaction.create!(
      user: user,
      account: source,
      destination_account: destination,
      transaction_category: category,
      transaction_kind: :transfer,
      transacted_at: Time.zone.parse("2026-05-04 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1500,
      destination_amount_cents: 1500
    )

    assert_equal(
      [ [ source, -1500 ], [ destination, 1500 ] ],
      transaction.balance_effects
    )
  end

  private

  def create_transaction_with_location(geo_latitude:, geo_longitude:)
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, category_type: :expense)

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-04 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1500,
      destination_amount_cents: 0,
      geo_latitude: geo_latitude,
      geo_longitude: geo_longitude
    )
  end

  def create_account(user:, name:)
    Account.create!(
      user: user,
      name: name,
      account_category: :checking_account,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "2563EB",
      currency_code: "USD",
      balance_cents: 0,
      display_order: 1
    )
  end

  def create_category(user:, category_type:)
    TransactionCategory.create!(
      user: user,
      name: category_type.to_s.humanize,
      category_type: category_type,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end
end
