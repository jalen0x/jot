require "test_helper"

class ImportBatchesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "requires authentication" do
    get new_import_batch_path

    assert_redirected_to new_user_session_path
  end

  test "new page describes supported import formats" do
    user = create(:user)
    sign_in user

    get new_import_batch_path

    assert_response :success
    assert_select "h1", text: /import transactions/i
    assert_select "p", text: /Paste CSV or TSV/i
    assert_select "label", text: /CSV or TSV/i
    assert_select "a[href='#{data_management_path}']", text: /Cancel/i
  end

  test "creates and processes an import batch" do
    user = create(:user)
    create_account(user: user, name: "Cash", balance_cents: 5_000)
    create_category(user: user, name: "Food", category_type: :expense)
    sign_in user

    perform_enqueued_jobs do
      post import_batches_path, params: {
        import_batch: {
          source_filename: "transactions.csv",
          raw_csv: csv_for(account: "Cash")
        }
      }
    end

    batch = user.import_batches.sole
    assert_redirected_to import_batch_path(batch)
    assert_predicate batch.reload, :imported?
    assert_equal 1, batch.imported_count
    assert_equal 1, user.transactions.count
  end

  test "rejects unsupported import source filename" do
    user = create(:user)
    sign_in user

    assert_no_enqueued_jobs only: ImportBatchParserJob do
      post import_batches_path, params: {
        import_batch: {
          source_filename: "transactions.xlsx",
          raw_csv: csv_for(account: "Cash")
        }
      }
    end

    assert_response :unprocessable_content
    assert_equal 0, user.import_batches.reload.count
    assert_match(/Source filename must be csv or tsv/i, response.body)
  end

  test "does not show another user's import batch" do
    user = create(:user)
    other_batch = ImportBatch.create!(user: create(:user), source_filename: "transactions.csv", raw_csv: csv_for(account: "Cash"))
    sign_in user

    get import_batch_path(other_batch)

    assert_response :not_found
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
