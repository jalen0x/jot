require "test_helper"
require "csv"

class DataExportTest < ActiveSupport::TestCase
  test "exports current user's transactions as CSV" do
    user = create(:user)
    other_user = create(:user)
    tag = create_tag(user: user, name: "Business")
    transaction = create_transaction(user: user, comment: "Client lunch", geo_latitude: 37.7749, geo_longitude: -122.4194)
    TransactionTagging.create!(user: user, ledger_transaction: transaction, transaction_tag: tag)
    create_transaction(user: other_user, comment: "Other lunch")

    csv = DataExport.new.transactions_csv(user: user)
    rows = CSV.parse(csv, headers: true)

    assert_equal [ "Transacted At", "Type", "Account", "Destination Account", "Category", "Source Amount Cents", "Destination Amount Cents", "Tags", "Comment", "Latitude", "Longitude" ], rows.headers
    assert_equal 1, rows.length
    assert_equal "Client lunch", rows[0]["Comment"]
    assert_equal "Business", rows[0]["Tags"]
    assert_equal "expense", rows[0]["Type"]
    assert_equal "37.7749", rows[0]["Latitude"]
    assert_equal "-122.4194", rows[0]["Longitude"]
  end

  private

  def create_transaction(user:, comment:, geo_latitude: nil, geo_longitude: nil)
    account = create_account(user: user, name: "Cash")
    category = create_category(user: user, name: "Food", category_type: :expense)

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1200,
      destination_amount_cents: 0,
      comment: comment,
      geo_latitude: geo_latitude,
      geo_longitude: geo_longitude
    )
  end

  def create_account(user:, name:)
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
end
