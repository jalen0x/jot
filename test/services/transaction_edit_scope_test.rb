require "test_helper"

class TransactionEditScopeTest < ActiveSupport::TestCase
  test "allows every transaction when scope is all" do
    transaction = build_transaction(transacted_at: "2026-05-01 10:00:00")

    assert TransactionEditScope.new.editable?(transaction: transaction, current_time: Time.zone.parse("2026-05-04 12:00:00"))
  end

  test "rejects every transaction when scope is none" do
    transaction = build_transaction(transaction_edit_scope: "none", transacted_at: "2026-05-04 10:00:00")

    refute TransactionEditScope.new.editable?(transaction: transaction, current_time: Time.zone.parse("2026-05-04 12:00:00"))
  end

  test "allows only today or later when scope is today or later" do
    current_time = Time.zone.parse("2026-05-04 12:00:00")
    today = build_transaction(transaction_edit_scope: "today_or_later", transacted_at: "2026-05-04 00:00:00")
    yesterday = build_transaction(transaction_edit_scope: "today_or_later", transacted_at: "2026-05-03 23:59:59")

    assert TransactionEditScope.new.editable?(transaction: today, current_time: current_time)
    refute TransactionEditScope.new.editable?(transaction: yesterday, current_time: current_time)
  end

  test "uses a rolling 24 hour window" do
    current_time = Time.zone.parse("2026-05-04 12:00:00")
    inside_window = build_transaction(transaction_edit_scope: "last_24_hours_or_later", transacted_at: "2026-05-03 12:00:01")
    outside_window = build_transaction(transaction_edit_scope: "last_24_hours_or_later", transacted_at: "2026-05-03 12:00:00")

    assert TransactionEditScope.new.editable?(transaction: inside_window, current_time: current_time)
    refute TransactionEditScope.new.editable?(transaction: outside_window, current_time: current_time)
  end

  test "uses the user's first day of week for this week scope" do
    current_time = Time.zone.parse("2026-05-06 12:00:00")
    sunday = build_transaction(transaction_edit_scope: "this_week_or_later", first_day_of_week: 1, transacted_at: "2026-05-03 23:59:59")
    monday = build_transaction(transaction_edit_scope: "this_week_or_later", first_day_of_week: 1, transacted_at: "2026-05-04 00:00:00")

    refute TransactionEditScope.new.editable?(transaction: sunday, current_time: current_time)
    assert TransactionEditScope.new.editable?(transaction: monday, current_time: current_time)
  end

  test "allows only this month or later when scope is this month or later" do
    current_time = Time.zone.parse("2026-05-04 12:00:00")
    this_month = build_transaction(transaction_edit_scope: "this_month_or_later", transacted_at: "2026-05-01 00:00:00")
    last_month = build_transaction(transaction_edit_scope: "this_month_or_later", transacted_at: "2026-04-30 23:59:59")

    assert TransactionEditScope.new.editable?(transaction: this_month, current_time: current_time)
    refute TransactionEditScope.new.editable?(transaction: last_month, current_time: current_time)
  end

  test "allows only this year or later when scope is this year or later" do
    current_time = Time.zone.parse("2026-05-04 12:00:00")
    this_year = build_transaction(transaction_edit_scope: "this_year_or_later", transacted_at: "2026-01-01 00:00:00")
    last_year = build_transaction(transaction_edit_scope: "this_year_or_later", transacted_at: "2025-12-31 23:59:59")

    assert TransactionEditScope.new.editable?(transaction: this_year, current_time: current_time)
    refute TransactionEditScope.new.editable?(transaction: last_year, current_time: current_time)
  end

  private

  def build_transaction(transaction_edit_scope: "all", first_day_of_week: 0, transacted_at:)
    user = create(:user)
    UserPreference.create!(
      user: user,
      default_currency_code: "USD",
      first_day_of_week: first_day_of_week,
      transaction_edit_scope: transaction_edit_scope
    )
    account = create_account(user: user)
    category = create_category(user: user)

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
      name: "Food",
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end
end
