require "test_helper"

class ImportFileParserTest < ActiveSupport::TestCase
  test "persists parsed rows from csv imports" do
    batch = import_batch(source_filename: "transactions.csv", raw_csv: csv_for(comment: "Client lunch"))

    ImportFileParser.new.parse_import_batch(import_batch: batch)

    row = batch.reload.parsed_rows.sole
    assert_equal "Cash", row["Account"]
    assert_equal "Food", row["Category"]
    assert_equal "Client lunch", row["Comment"]
  end

  test "persists parsed rows from tsv imports" do
    batch = import_batch(source_filename: "transactions.tsv", raw_csv: tsv_for(comment: "Client lunch"))

    ImportFileParser.new.parse_import_batch(import_batch: batch)

    row = batch.reload.parsed_rows.sole
    assert_equal "Cash", row["Account"]
    assert_equal "Client lunch", row["Comment"]
  end

  test "normalizes json imports to transaction row snapshots" do
    batch = import_batch(source_filename: "transactions.json", raw_csv: json_for(comment: "Client lunch"))

    ImportFileParser.new.parse_import_batch(import_batch: batch)

    row = batch.reload.parsed_rows.sole
    assert_equal "2026-05-03T10:00:00Z", row["Transacted At"]
    assert_equal "expense", row["Type"]
    assert_equal "Cash", row["Account"]
    assert_equal "Business; Travel", row["Tags"]
    assert_equal true, row["Hide Amount"]
    assert_equal "37.7749", row["Latitude"]
  end

  test "rejects json imports without a transactions array" do
    batch = import_batch(source_filename: "transactions.json", raw_csv: "{}")

    error = assert_raises(ImportFileParser::ParseError) do
      ImportFileParser.new.parse_import_batch(import_batch: batch)
    end

    assert_equal "JSON import must include a transactions array", error.message
    assert_nil batch.reload.parsed_rows
  end

  test "rejects json imports with missing required transaction fields" do
    raw_json = { transactions: [ { account_name: "Cash" } ] }.to_json
    batch = import_batch(source_filename: "transactions.json", raw_csv: raw_json)

    error = assert_raises(ImportFileParser::ParseError) do
      ImportFileParser.new.parse_import_batch(import_batch: batch)
    end

    assert_equal "JSON transaction is missing transacted_at", error.message
    assert_nil batch.reload.parsed_rows
  end

  test "rejects json transaction rows that are not objects" do
    batch = import_batch(source_filename: "transactions.json", raw_csv: { transactions: [ "not a row" ] }.to_json)

    error = assert_raises(ImportFileParser::ParseError) do
      ImportFileParser.new.parse_import_batch(import_batch: batch)
    end

    assert_equal "JSON transaction must be an object", error.message
    assert_nil batch.reload.parsed_rows
  end

  private

  def import_batch(source_filename:, raw_csv:)
    ImportBatch.create!(user: create(:user), source_filename: source_filename, raw_csv: raw_csv)
  end

  def csv_for(comment:)
    <<~CSV
      Transacted At,Timezone UTC Offset Minutes,Type,Account,Destination Account,Category,Source Amount Cents,Destination Amount Cents,Tags,Hide Amount,Comment,Latitude,Longitude
      2026-05-03T10:00:00Z,480,expense,Cash,,Food,1200,0,Business,true,#{comment},37.7749,-122.4194
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
          transaction_tag_names: [ "Business", "Travel" ],
          hide_amount: true,
          comment: comment,
          geo_latitude: "37.7749",
          geo_longitude: "-122.4194"
        }
      ]
    )
  end
end
