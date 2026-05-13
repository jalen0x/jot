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

  # ----- editable? -----

  test "editable? is true when transacted_at is blank" do
    user = create(:user)
    transaction = user.transactions.build(transacted_at: nil)

    assert_predicate transaction, :editable?
  end

  test "editable? allows every transaction when scope is all" do
    transaction = build_editable_transaction(transacted_at: "2026-05-01 10:00:00")

    assert transaction.editable?(current_time: Time.zone.parse("2026-05-04 12:00:00"))
  end

  test "editable? rejects every transaction when scope is none" do
    transaction = build_editable_transaction(transaction_edit_scope: "none", transacted_at: "2026-05-04 10:00:00")

    refute transaction.editable?(current_time: Time.zone.parse("2026-05-04 12:00:00"))
  end

  test "editable? allows only today or later when scope is today_or_later" do
    current_time = Time.zone.parse("2026-05-04 12:00:00")
    today = build_editable_transaction(transaction_edit_scope: "today_or_later", transacted_at: "2026-05-04 00:00:00")
    yesterday = build_editable_transaction(transaction_edit_scope: "today_or_later", transacted_at: "2026-05-03 23:59:59")

    assert today.editable?(current_time: current_time)
    refute yesterday.editable?(current_time: current_time)
  end

  test "editable? uses a rolling 24 hour window" do
    current_time = Time.zone.parse("2026-05-04 12:00:00")
    inside_window = build_editable_transaction(transaction_edit_scope: "last_24_hours_or_later", transacted_at: "2026-05-03 12:00:01")
    outside_window = build_editable_transaction(transaction_edit_scope: "last_24_hours_or_later", transacted_at: "2026-05-03 12:00:00")

    assert inside_window.editable?(current_time: current_time)
    refute outside_window.editable?(current_time: current_time)
  end

  test "editable? uses the user's first day of week for this_week_or_later" do
    current_time = Time.zone.parse("2026-05-06 12:00:00")
    sunday = build_editable_transaction(transaction_edit_scope: "this_week_or_later", first_day_of_week: 1, transacted_at: "2026-05-03 23:59:59")
    monday = build_editable_transaction(transaction_edit_scope: "this_week_or_later", first_day_of_week: 1, transacted_at: "2026-05-04 00:00:00")

    refute sunday.editable?(current_time: current_time)
    assert monday.editable?(current_time: current_time)
  end

  test "editable? allows only this month or later when scope is this_month_or_later" do
    current_time = Time.zone.parse("2026-05-04 12:00:00")
    this_month = build_editable_transaction(transaction_edit_scope: "this_month_or_later", transacted_at: "2026-05-01 00:00:00")
    last_month = build_editable_transaction(transaction_edit_scope: "this_month_or_later", transacted_at: "2026-04-30 23:59:59")

    assert this_month.editable?(current_time: current_time)
    refute last_month.editable?(current_time: current_time)
  end

  test "editable? allows only this year or later when scope is this_year_or_later" do
    current_time = Time.zone.parse("2026-05-04 12:00:00")
    this_year = build_editable_transaction(transaction_edit_scope: "this_year_or_later", transacted_at: "2026-01-01 00:00:00")
    last_year = build_editable_transaction(transaction_edit_scope: "this_year_or_later", transacted_at: "2025-12-31 23:59:59")

    assert this_year.editable?(current_time: current_time)
    refute last_year.editable?(current_time: current_time)
  end

  private

  def build_editable_transaction(transaction_edit_scope: "all", first_day_of_week: 0, transacted_at:)
    user = create(:user)
    UserPreference.create!(
      user: user,
      default_currency_code: "USD",
      first_day_of_week: first_day_of_week,
      transaction_edit_scope: transaction_edit_scope
    )
    account = create_account(user: user, name: "Cash")
    category = create_category(user: user, category_type: :expense)

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse(transacted_at),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1_000,
      destination_amount_cents: 0,
      comment: "Lunch"
    )
  end

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
