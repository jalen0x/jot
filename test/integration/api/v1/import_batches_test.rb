require "test_helper"

class ApiV1ImportBatchesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "creates an import batch for the token owner" do
    user = create(:user)
    raw_token = issue_token(user)

    assert_enqueued_jobs 1, only: ImportBatchParserJob do
      post api_v1_import_batches_path,
        params: {
          import_batch: {
            source_filename: "transactions.csv",
            raw_csv: csv_for(account: "Cash")
          }
        },
        headers: json_headers(raw_token),
        as: :json
    end

    assert_response :created
    batch = user.import_batches.sole
    assert_predicate batch, :pending?
    assert_equal [ batch.id ], enqueued_jobs.sole.fetch(:args)

    batch_json = JSON.parse(response.body).fetch("import_batch")
    assert_equal batch.to_param, batch_json.fetch("id")
    assert_equal "transactions.csv", batch_json.fetch("source_filename")
    assert_equal "pending", batch_json.fetch("status")
    assert_equal 0, batch_json.fetch("imported_count")
    assert_equal "", batch_json.fetch("error_message")
    refute_includes batch_json.keys, "user_id"
    refute_includes batch_json.keys, "raw_csv"
  end

  test "shows one import batch for the token owner" do
    user = create(:user)
    batch = ImportBatch.create!(user: user, source_filename: "transactions.csv", raw_csv: csv_for(account: "Cash"), status: :failed, error_message: "Account not found")
    raw_token = issue_token(user)

    get api_v1_import_batch_path(batch), headers: json_headers(raw_token)

    assert_response :success
    batch_json = JSON.parse(response.body).fetch("import_batch")
    assert_equal batch.to_param, batch_json.fetch("id")
    assert_equal "transactions.csv", batch_json.fetch("source_filename")
    assert_equal "failed", batch_json.fetch("status")
    assert_equal 0, batch_json.fetch("imported_count")
    assert_equal "Account not found", batch_json.fetch("error_message")
    refute_includes batch_json.keys, "user_id"
    refute_includes batch_json.keys, "raw_csv"
  end

  test "does not show another user's import batch" do
    user = create(:user)
    batch = ImportBatch.create!(user: create(:user), source_filename: "transactions.csv", raw_csv: csv_for(account: "Cash"))
    raw_token = issue_token(user)

    get api_v1_import_batch_path(batch), headers: json_headers(raw_token)

    assert_response :not_found
  end

  test "rejects invalid import batch params" do
    user = create(:user)
    raw_token = issue_token(user)

    assert_no_enqueued_jobs only: ImportBatchParserJob do
      post api_v1_import_batches_path,
        params: { import_batch: { source_filename: "transactions.csv", raw_csv: "" } },
        headers: json_headers(raw_token),
        as: :json
    end

    assert_response :unprocessable_content
    assert_empty user.import_batches
    assert_match(/Raw csv/i, response.body)
  end

  private

  def issue_token(user)
    ApiTokenIssuer.new.issue(user: user, attributes: { name: "API", expires_in_days: "" }).raw_token
  end

  def json_headers(raw_token)
    {
      "Accept" => "application/json",
      "Authorization" => "Bearer #{raw_token}"
    }
  end

  def csv_for(account:)
    <<~CSV
      Transacted At,Type,Account,Destination Account,Category,Source Amount Cents,Destination Amount Cents,Tags,Comment
      2026-05-03T10:00:00Z,expense,#{account},,Food,1200,0,,Lunch
    CSV
  end
end
