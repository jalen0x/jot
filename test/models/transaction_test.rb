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

  private

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
