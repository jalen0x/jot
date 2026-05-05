require "test_helper"

class ImportBatchParserJobTest < ActiveJob::TestCase
  test "imports a pending batch" do
    user = create(:user)
    create_account(user: user, name: "Cash", balance_cents: 5_000)
    create_category(user: user, name: "Food", category_type: :expense)
    batch = ImportBatch.create!(user: user, source_filename: "transactions.csv", raw_csv: csv_for(account: "Cash"))

    ImportBatchParserJob.perform_now(batch.id)

    assert_predicate batch.reload, :imported?
    assert_equal 1, batch.imported_count
    assert_equal "Cash", batch.parsed_rows.sole["Account"]
  end

  test "marks user input errors as failed" do
    user = create(:user)
    create_category(user: user, name: "Food", category_type: :expense)
    batch = ImportBatch.create!(user: user, source_filename: "transactions.csv", raw_csv: csv_for(account: "Missing"))

    error = assert_raises(TransactionImporter::ImportError) do
      ImportBatchParserJob.perform_now(batch.id)
    end

    assert_predicate batch.reload, :failed?
    assert_equal "Account not found: Missing", error.message
    assert_equal "Account not found: Missing", batch.error_message
  end

  test "marks invalid json imports as failed" do
    user = create(:user)
    batch = ImportBatch.create!(user: user, source_filename: "transactions.json", raw_csv: "{}")

    error = assert_raises(ImportFileParser::ParseError) do
      ImportBatchParserJob.perform_now(batch.id)
    end

    assert_predicate batch.reload, :failed?
    assert_equal "JSON import must include a transactions array", error.message
    assert_equal "JSON import must include a transactions array", batch.error_message
  end

  test "marks json imports with missing required transaction fields as failed" do
    user = create(:user)
    raw_json = {
      transactions: [
        {
          transacted_at: "2026-05-03T10:00:00Z",
          transaction_kind: "expense",
          transaction_category_name: "Food",
          source_amount_cents: 1200
        }
      ]
    }.to_json
    batch = ImportBatch.create!(user: user, source_filename: "transactions.json", raw_csv: raw_json)

    error = assert_raises(ImportFileParser::ParseError) do
      ImportBatchParserJob.perform_now(batch.id)
    end

    assert_predicate batch.reload, :failed?
    assert_equal "JSON transaction is missing account_name", error.message
    assert_equal "JSON transaction is missing account_name", batch.error_message
  end

  test "skips already imported batches" do
    user = create(:user)
    batch = ImportBatch.create!(user: user, source_filename: "transactions.json", raw_csv: "{}", status: :imported, imported_count: 1)

    assert_no_changes -> { user.transactions.count } do
      ImportBatchParserJob.perform_now(batch.id)
    end

    assert_predicate batch.reload, :imported?
    assert_equal 1, batch.imported_count
  end

  private

  def csv_for(account:)
    <<~CSV
      Transacted At,Type,Account,Destination Account,Category,Source Amount Cents,Destination Amount Cents,Tags,Comment
      2026-05-03T10:00:00Z,expense,#{account},,Food,1200,0,,Lunch
    CSV
  end

  def create_account(user:, name:, balance_cents:)
    Account.create!(user: user, name: name, account_category: :cash, account_structure: :single_account, icon_key: 1, color_hex: "22C55E", currency_code: "USD", balance_cents: balance_cents, display_order: 1)
  end

  def create_category(user:, name:, category_type:)
    TransactionCategory.create!(user: user, name: name, category_type: category_type, icon_key: 1, color_hex: "F97316", display_order: 1)
  end
end
