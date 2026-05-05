require "test_helper"

class TransactionImporterTest < ActiveSupport::TestCase
  test "imports parsed transaction rows through TransactionRecorder" do
    user = create(:user)
    account = create_account(user: user, name: "Cash", balance_cents: 5_000)
    create_category(user: user, name: "Food", category_type: :expense)
    create_tag(user: user, name: "Business")
    batch = parsed_batch(user: user, rows: [ row_for(comment: "Client lunch") ])

    TransactionImporter.new.import_transactions(import_batch: batch)

    assert_predicate batch.reload, :imported?
    assert_equal 1, batch.imported_count
    transaction = user.transactions.sole
    assert_equal "Client lunch", transaction.comment
    assert_equal [ "Business" ], transaction.transaction_tags.map(&:name)
    assert_equal 480, transaction.timezone_utc_offset_minutes
    assert_equal true, transaction.hide_amount
    assert_equal BigDecimal("37.7749"), transaction.geo_latitude
    assert_equal BigDecimal("-122.4194"), transaction.geo_longitude
    assert_equal 3_800, account.reload.balance_cents
  end

  test "raises import error when account is missing" do
    user = create(:user)
    create_category(user: user, name: "Food", category_type: :expense)
    batch = parsed_batch(user: user, rows: [ row_for(comment: "Client lunch") ])

    error = assert_raises(TransactionImporter::ImportError) do
      TransactionImporter.new.import_transactions(import_batch: batch)
    end

    assert_equal "Account not found: Cash", error.message
    assert_empty user.transactions
  end

  test "rejects imported rows outside the user's transaction edit scope" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD", transaction_edit_scope: "today_or_later")
    account = create_account(user: user, name: "Cash", balance_cents: 5_000)
    create_category(user: user, name: "Food", category_type: :expense)
    create_tag(user: user, name: "Business")
    batch = parsed_batch(user: user, rows: [ row_for(comment: "Client lunch") ])

    travel_to Time.zone.parse("2026-05-04 12:00:00") do
      error = assert_raises(TransactionImporter::ImportError) do
        TransactionImporter.new.import_transactions(import_batch: batch)
      end

      assert_match(/Transaction is outside the editable date range/i, error.message)
    end
    assert_predicate batch.reload, :pending?
    assert_equal 0, user.transactions.reload.count
    assert_equal 5_000, account.reload.balance_cents
  end

  test "imports balance adjustment rows without categories" do
    user = create(:user)
    account = create_account(user: user, name: "Cash", balance_cents: 0)
    batch = parsed_batch(
      user: user,
      rows: [ row_for(transaction_kind: "balance_adjustment", category: nil, source_amount_cents: "5000", comment: "Opening balance", hide_amount: "false", tags: "") ]
    )

    TransactionImporter.new.import_transactions(import_batch: batch)

    assert_predicate batch.reload, :imported?
    transaction = user.transactions.sole
    assert_predicate transaction, :balance_adjustment?
    assert_nil transaction.transaction_category
    assert_equal 5_000, account.reload.balance_cents
  end

  test "imports parsed json row values" do
    user = create(:user)
    account = create_account(user: user, name: "Cash", balance_cents: 5_000)
    create_category(user: user, name: "Food", category_type: :expense)
    create_tag(user: user, name: "Business")
    batch = parsed_batch(
      user: user,
      rows: [ row_for(comment: "Client lunch", timezone_utc_offset_minutes: 0, source_amount_cents: 1200, hide_amount: true) ]
    )

    TransactionImporter.new.import_transactions(import_batch: batch)

    assert_predicate batch.reload, :imported?
    transaction = user.transactions.sole
    assert_equal "Client lunch", transaction.comment
    assert_equal [ "Business" ], transaction.transaction_tags.map(&:name)
    assert_equal true, transaction.hide_amount
    assert_equal BigDecimal("37.7749"), transaction.geo_latitude
    assert_equal BigDecimal("-122.4194"), transaction.geo_longitude
    assert_equal 3_800, account.reload.balance_cents
  end

  test "rolls back imported rows when a later row fails" do
    user = create(:user)
    account = create_account(user: user, name: "Cash", balance_cents: 5_000)
    create_category(user: user, name: "Food", category_type: :expense)
    batch = parsed_batch(
      user: user,
      rows: [ row_for(comment: "Lunch", tags: ""), row_for(category: "Missing", comment: "Coffee", tags: "") ]
    )

    error = assert_raises(TransactionImporter::ImportError) do
      TransactionImporter.new.import_transactions(import_batch: batch)
    end

    assert_equal "Category not found: Missing", error.message
    assert_predicate batch.reload, :pending?
    assert_equal 0, user.transactions.count
    assert_equal 5_000, account.reload.balance_cents
  end

  test "raises import error when parsed rows are missing required fields" do
    user = create(:user)
    batch = parsed_batch(user: user, rows: [ row_for.except("Account") ])

    error = assert_raises(TransactionImporter::ImportError) do
      TransactionImporter.new.import_transactions(import_batch: batch)
    end

    assert_equal "Import row is missing Account", error.message
    assert_predicate batch.reload, :pending?
  end

  private

  def parsed_batch(user:, rows:)
    ImportBatch.create!(user: user, source_filename: "transactions.csv", raw_csv: "raw import payload", parsed_rows: rows)
  end

  def row_for(
    transaction_kind: "expense",
    account: "Cash",
    category: "Food",
    source_amount_cents: "1200",
    tags: "Business",
    hide_amount: "true",
    comment: "Lunch",
    timezone_utc_offset_minutes: "480"
  )
    {
      "Transacted At" => "2026-05-03T10:00:00Z",
      "Timezone UTC Offset Minutes" => timezone_utc_offset_minutes,
      "Type" => transaction_kind,
      "Account" => account,
      "Destination Account" => nil,
      "Category" => category,
      "Source Amount Cents" => source_amount_cents,
      "Destination Amount Cents" => "0",
      "Tags" => tags,
      "Hide Amount" => hide_amount,
      "Comment" => comment,
      "Latitude" => "37.7749",
      "Longitude" => "-122.4194"
    }
  end

  def create_account(user:, name:, balance_cents:)
    Account.create!(
      user: user,
      name: name,
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
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
end
