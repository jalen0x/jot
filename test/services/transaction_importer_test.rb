require "test_helper"

class TransactionImporterTest < ActiveSupport::TestCase
  test "imports exported transaction rows through TransactionRecorder" do
    user = create(:user)
    account = create_account(user: user, name: "Cash", balance_cents: 5_000)
    create_category(user: user, name: "Food", category_type: :expense)
    create_tag(user: user, name: "Business")
    batch = ImportBatch.create!(user: user, source_filename: "transactions.csv", raw_csv: csv_for(comment: "Client lunch"))

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
    batch = ImportBatch.create!(user: user, source_filename: "transactions.csv", raw_csv: csv_for(comment: "Client lunch"))

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
    batch = ImportBatch.create!(user: user, source_filename: "transactions.csv", raw_csv: csv_for(comment: "Client lunch"))

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
    batch = ImportBatch.create!(user: user, source_filename: "transactions.csv", raw_csv: balance_adjustment_csv)

    TransactionImporter.new.import_transactions(import_batch: batch)

    assert_predicate batch.reload, :imported?
    transaction = user.transactions.sole
    assert_predicate transaction, :balance_adjustment?
    assert_nil transaction.transaction_category
    assert_equal 5_000, account.reload.balance_cents
  end

  test "imports tab-separated transaction rows from tsv files" do
    user = create(:user)
    account = create_account(user: user, name: "Cash", balance_cents: 5_000)
    create_category(user: user, name: "Food", category_type: :expense)
    batch = ImportBatch.create!(user: user, source_filename: "transactions.tsv", raw_csv: tsv_for(comment: "Client lunch"))

    TransactionImporter.new.import_transactions(import_batch: batch)

    assert_predicate batch.reload, :imported?
    transaction = user.transactions.sole
    assert_equal "Client lunch", transaction.comment
    assert_equal 3_800, account.reload.balance_cents
  end

  test "imports json transaction rows from json files" do
    user = create(:user)
    account = create_account(user: user, name: "Cash", balance_cents: 5_000)
    create_category(user: user, name: "Food", category_type: :expense)
    create_tag(user: user, name: "Business")
    batch = ImportBatch.create!(user: user, source_filename: "transactions.json", raw_csv: json_for(comment: "Client lunch"))

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
    batch = ImportBatch.create!(user: user, source_filename: "transactions.csv", raw_csv: partial_failure_csv)

    error = assert_raises(TransactionImporter::ImportError) do
      TransactionImporter.new.import_transactions(import_batch: batch)
    end

    assert_equal "Category not found: Missing", error.message
    assert_predicate batch.reload, :pending?
    assert_equal 0, user.transactions.count
    assert_equal 5_000, account.reload.balance_cents
  end

  private

  def csv_for(comment:)
    <<~CSV
      Transacted At,Timezone UTC Offset Minutes,Type,Account,Destination Account,Category,Source Amount Cents,Destination Amount Cents,Tags,Hide Amount,Comment,Latitude,Longitude
      2026-05-03T10:00:00Z,480,expense,Cash,,Food,1200,0,Business,true,#{comment},37.7749,-122.4194
    CSV
  end

  def balance_adjustment_csv
    <<~CSV
      Transacted At,Timezone UTC Offset Minutes,Type,Account,Destination Account,Category,Source Amount Cents,Destination Amount Cents,Tags,Hide Amount,Comment,Latitude,Longitude
      2026-05-03T10:00:00Z,0,balance_adjustment,Cash,,,5000,0,,false,Opening balance,,
    CSV
  end

  def tsv_for(comment:)
    [
      [ "Transacted At", "Timezone UTC Offset Minutes", "Type", "Account", "Destination Account", "Category", "Source Amount Cents", "Destination Amount Cents", "Tags", "Hide Amount", "Comment", "Latitude", "Longitude" ].join("\t"),
      [ "2026-05-03T10:00:00Z", "0", "expense", "Cash", "", "Food", "1200", "0", "", "false", comment, "", "" ].join("\t")
    ].join("\n")
  end

  def json_for(comment:)
    JSON.generate(
      transactions: [
        {
          transacted_at: "2026-05-03T10:00:00Z",
          timezone_utc_offset_minutes: 0,
          transaction_kind: "expense",
          account_name: "Cash",
          destination_account_name: nil,
          transaction_category_name: "Food",
          source_amount_cents: 1200,
          destination_amount_cents: 0,
          transaction_tag_names: [ "Business" ],
          hide_amount: true,
          comment: comment,
          geo_latitude: "37.7749",
          geo_longitude: "-122.4194"
        }
      ]
    )
  end

  def partial_failure_csv
    <<~CSV
      Transacted At,Timezone UTC Offset Minutes,Type,Account,Destination Account,Category,Source Amount Cents,Destination Amount Cents,Tags,Hide Amount,Comment,Latitude,Longitude
      2026-05-03T10:00:00Z,0,expense,Cash,,Food,1200,0,,false,Lunch,,
      2026-05-04T10:00:00Z,0,expense,Cash,,Missing,400,0,,false,Coffee,,
    CSV
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
