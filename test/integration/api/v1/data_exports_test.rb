require "test_helper"
require "csv"

class ApiV1DataExportsTest < ActionDispatch::IntegrationTest
  test "exports the token owner's transaction CSV" do
    user = create(:user)
    other_user = create(:user)
    create_transaction(user: user, comment: "Client lunch")
    create_transaction(user: other_user, comment: "Other lunch")
    raw_token = issue_token(user)

    post api_v1_data_exports_path, headers: csv_headers(raw_token)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match(/transactions-\d{4}-\d{2}-\d{2}\.csv/, response.headers.fetch("Content-Disposition"))
    rows = CSV.parse(response.body, headers: true)
    assert_equal [ "Client lunch" ], rows.map { |row| row["Comment"] }
  end

  test "exports the token owner's transaction TSV" do
    user = create(:user)
    create_transaction(user: user, comment: "Client lunch")
    raw_token = issue_token(user)

    post api_v1_data_exports_path,
      params: { file_format: "tsv" },
      headers: tsv_headers(raw_token)

    assert_response :success
    assert_equal "text/tab-separated-values", response.media_type
    assert_match(/transactions-\d{4}-\d{2}-\d{2}\.tsv/, response.headers.fetch("Content-Disposition"))
    rows = CSV.parse(response.body, headers: true, col_sep: "\t")
    assert_equal [ "Client lunch" ], rows.map { |row| row["Comment"] }
  end

  test "exports the token owner's transaction JSON" do
    user = create(:user)
    other_user = create(:user)
    create_transaction(user: user, comment: "Client lunch")
    create_transaction(user: other_user, comment: "Other lunch")
    raw_token = issue_token(user)

    post api_v1_data_exports_path,
      params: { file_format: "json" },
      headers: json_headers(raw_token)

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match(/transactions-\d{4}-\d{2}-\d{2}\.json/, response.headers.fetch("Content-Disposition"))
    transactions = JSON.parse(response.body).fetch("transactions")
    assert_equal [ "Client lunch" ], transactions.map { |transaction| transaction.fetch("comment") }
  end

  test "exports filtered transaction CSV" do
    user = create(:user)
    checking = create_account(user: user, name: "Checking")
    savings = create_account(user: user, name: "Savings")
    category = create_category(user: user, name: "Food", category_type: :expense)
    create_transaction(user: user, account: checking, category: category, comment: "Client lunch")
    create_transaction(user: user, account: savings, category: category, comment: "Client coffee")
    create_transaction(user: user, account: checking, category: category, comment: "Family lunch")
    raw_token = issue_token(user)

    post api_v1_data_exports_path,
      params: { account_ids: [ checking.to_param ], keyword: "client" },
      headers: csv_headers(raw_token)

    assert_response :success
    rows = CSV.parse(response.body, headers: true)
    assert_equal [ "Client lunch" ], rows.map { |row| row["Comment"] }
  end

  test "requires token authentication" do
    post api_v1_data_exports_path, headers: { "Accept" => "text/csv" }

    assert_response :unauthorized
  end

  test "rejects unsupported export formats" do
    user = create(:user)
    raw_token = issue_token(user)

    post api_v1_data_exports_path,
      params: { file_format: "xlsx" },
      headers: csv_headers(raw_token)

    assert_response :unprocessable_content
    body = JSON.parse(response.body)
    assert_equal [ "File format must be csv, tsv, or json" ], body.fetch("errors")
  end

  private

  def issue_token(user)
    ApiTokenIssuer.new.issue(user: user, attributes: { name: "API", expires_in_days: "" }).raw_token
  end

  def csv_headers(raw_token)
    {
      "Accept" => "text/csv",
      "Authorization" => "Bearer #{raw_token}"
    }
  end

  def tsv_headers(raw_token)
    {
      "Accept" => "text/tab-separated-values",
      "Authorization" => "Bearer #{raw_token}"
    }
  end

  def json_headers(raw_token)
    {
      "Accept" => "application/json",
      "Authorization" => "Bearer #{raw_token}"
    }
  end

  def create_transaction(user:, comment:, account: nil, category: nil)
    account ||= create_account(user: user, name: "Cash")
    category ||= create_category(user: user, name: "Food", category_type: :expense)

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1200,
      destination_amount_cents: 0,
      comment: comment
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
end
