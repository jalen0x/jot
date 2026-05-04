require "test_helper"

class ApiV1TransactionsTest < ActionDispatch::IntegrationTest
  test "lists only the token owner's kept transactions" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking")
    income_category = create_category(user: user, name: "Salary", category_type: :income)
    expense_category = create_category(user: user, name: "Food", category_type: :expense)
    tag = create_tag(user: user, name: "Payroll")
    income = create_transaction(
      user: user,
      account: account,
      category: income_category,
      transaction_kind: :income,
      transacted_at: Time.zone.parse("2026-05-03 11:00:00"),
      source_amount_cents: 200_000,
      comment: "Paycheck",
      tags: [ tag ],
      geo_latitude: 37.7749,
      geo_longitude: -122.4194
    )
    expense = create_transaction(
      user: user,
      account: account,
      category: expense_category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      source_amount_cents: 1_200,
      comment: "Lunch"
    )
    discarded_transaction = create_transaction(
      user: user,
      account: account,
      category: expense_category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 500,
      comment: "Archived"
    )
    discarded_transaction.discard!
    create_transaction(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Salary", category_type: :income),
      transaction_kind: :income,
      transacted_at: Time.zone.parse("2026-05-03 12:30:00"),
      source_amount_cents: 300_000,
      comment: "Other Paycheck"
    )
    raw_token = issue_token(user)

    get api_v1_transactions_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "transactions" ], body.keys
    transactions = body.fetch("transactions")
    assert_equal [ income.to_param, expense.to_param ], transactions.map { |item| item.fetch("id") }

    income_json = transactions.first
    assert_equal "income", income_json.fetch("transaction_kind")
    assert_equal account.to_param, income_json.fetch("account_id")
    assert_nil income_json.fetch("destination_account_id")
    assert_equal income_category.to_param, income_json.fetch("transaction_category_id")
    assert_equal income.transacted_at.iso8601, income_json.fetch("transacted_at")
    assert_equal 0, income_json.fetch("timezone_utc_offset_minutes")
    assert_equal 200_000, income_json.fetch("source_amount_cents")
    assert_equal 0, income_json.fetch("destination_amount_cents")
    assert_equal false, income_json.fetch("hide_amount")
    assert_equal "Paycheck", income_json.fetch("comment")
    assert_equal({ "latitude" => "37.7749", "longitude" => "-122.4194" }, income_json.fetch("geo_location"))
    assert_equal [ tag.to_param ], income_json.fetch("transaction_tag_ids")
    refute_includes income_json.keys, "user_id"
  end

  test "filters transactions by kind" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    income = create_transaction(
      user: user,
      account: account,
      category: create_category(user: user, name: "Salary", category_type: :income),
      transaction_kind: :income,
      transacted_at: Time.zone.parse("2026-05-03 11:00:00"),
      source_amount_cents: 200_000,
      comment: "Paycheck"
    )
    create_transaction(
      user: user,
      account: account,
      category: create_category(user: user, name: "Food", category_type: :expense),
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      source_amount_cents: 1_200,
      comment: "Lunch"
    )
    raw_token = issue_token(user)

    get api_v1_transactions_path, params: { transaction_kind: "income" }, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ income.to_param ], body.fetch("transactions").map { |item| item.fetch("id") }
  end

  test "filters transactions by prefixed account id" do
    user = create(:user)
    matching_account = create_account(user: user, name: "Checking")
    other_account = create_account(user: user, name: "Savings")
    category = create_category(user: user, name: "Food", category_type: :expense)
    matching = create_transaction(
      user: user,
      account: matching_account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 11:00:00"),
      source_amount_cents: 1_200,
      comment: "Lunch"
    )
    create_transaction(
      user: user,
      account: other_account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      source_amount_cents: 900,
      comment: "Coffee"
    )
    other_user = create(:user)
    create_transaction(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Food", category_type: :expense),
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 800,
      comment: "Other Lunch"
    )
    raw_token = issue_token(user)

    get api_v1_transactions_path, params: { account_id: matching_account.to_param }, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ matching.to_param ], body.fetch("transactions").map { |item| item.fetch("id") }
  end

  test "filters transactions by prefixed category id" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    matching_category = create_category(user: user, name: "Food", category_type: :expense)
    other_category = create_category(user: user, name: "Travel", category_type: :expense)
    matching = create_transaction(
      user: user,
      account: account,
      category: matching_category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 11:00:00"),
      source_amount_cents: 1_200,
      comment: "Lunch"
    )
    create_transaction(
      user: user,
      account: account,
      category: other_category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      source_amount_cents: 9_000,
      comment: "Flight"
    )
    raw_token = issue_token(user)

    get api_v1_transactions_path, params: { transaction_category_id: matching_category.to_param }, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ matching.to_param ], body.fetch("transactions").map { |item| item.fetch("id") }
  end

  test "filters transactions by prefixed tag id" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Food", category_type: :expense)
    matching_tag = create_tag(user: user, name: "Business")
    other_tag = create_tag(user: user, name: "Personal")
    matching = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 11:00:00"),
      source_amount_cents: 1_200,
      comment: "Lunch",
      tags: [ matching_tag ]
    )
    create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      source_amount_cents: 900,
      comment: "Coffee",
      tags: [ other_tag ]
    )
    raw_token = issue_token(user)

    get api_v1_transactions_path, params: { tag_id: matching_tag.to_param }, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ matching.to_param ], body.fetch("transactions").map { |item| item.fetch("id") }
  end

  test "creates an expense transaction for the token owner" do
    user = create(:user)
    account = create_account(user: user, name: "Checking", balance_cents: 5_000)
    category = create_category(user: user, name: "Food", category_type: :expense)
    tag = create_tag(user: user, name: "Meals")
    raw_token = issue_token(user)

    post api_v1_transactions_path,
      params: {
        transaction: {
          transaction_kind: "expense",
          account_id: account.to_param,
          transaction_category_id: category.to_param,
          transacted_at: "2026-05-03 12:00:00",
          timezone_utc_offset_minutes: "0",
          source_amount_cents: "1250",
          destination_amount_cents: "0",
          hide_amount: "false",
          comment: "Lunch",
          geo_location: { latitude: "37.7749", longitude: "-122.4194" },
          transaction_tag_ids: [ tag.to_param ]
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :created
    transaction = user.transactions.where(comment: "Lunch").sole
    assert_equal 3_750, account.reload.balance_cents
    assert_equal [ tag ], transaction.transaction_tags.to_a

    body = JSON.parse(response.body)
    transaction_json = body.fetch("transaction")
    assert_equal transaction.to_param, transaction_json.fetch("id")
    assert_equal account.to_param, transaction_json.fetch("account_id")
    assert_equal category.to_param, transaction_json.fetch("transaction_category_id")
    assert_equal [ tag.to_param ], transaction_json.fetch("transaction_tag_ids")
    assert_equal({ "latitude" => "37.7749", "longitude" => "-122.4194" }, transaction_json.fetch("geo_location"))
    refute_includes transaction_json.keys, "user_id"
  end

  test "rejects another user's account and transaction category" do
    user = create(:user)
    other_user = create(:user)
    other_account = create_account(user: other_user, name: "Other Checking", balance_cents: 5_000)
    other_category = create_category(user: other_user, name: "Other Food", category_type: :expense)
    raw_token = issue_token(user)

    post api_v1_transactions_path,
      params: {
        transaction: {
          transaction_kind: "expense",
          account_id: other_account.to_param,
          transaction_category_id: other_category.to_param,
          transacted_at: "2026-05-03 12:00:00",
          timezone_utc_offset_minutes: "0",
          source_amount_cents: "1250",
          destination_amount_cents: "0",
          hide_amount: "false",
          comment: "Lunch"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_empty user.transactions.where(comment: "Lunch")
    assert_equal 5_000, other_account.reload.balance_cents
    assert_match(/Account is unavailable/i, response.body)
    assert_match(/Transaction category is unavailable/i, response.body)
  end

  test "uploads and lists pictures for a token owner's transaction" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Food", category_type: :expense)
    transaction = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    raw_token = issue_token(user)

    post api_v1_transaction_pictures_path(transaction),
      params: { picture: fixture_file_upload("receipt.txt", "text/plain") },
      headers: json_headers(raw_token)

    assert_response :created
    attachment = transaction.pictures.attachments.sole
    body = JSON.parse(response.body)
    picture_json = body.fetch("picture")
    assert_equal attachment.id, picture_json.fetch("id")
    assert_equal "receipt.txt", picture_json.fetch("filename")
    assert_equal "text/plain", picture_json.fetch("content_type")
    assert_equal attachment.byte_size, picture_json.fetch("byte_size")
    assert_match(%r{/rails/active_storage/blobs/}, picture_json.fetch("url"))
    refute_includes picture_json.keys, "user_id"

    get api_v1_transaction_pictures_path(transaction), headers: json_headers(raw_token)

    assert_response :success
    pictures = JSON.parse(response.body).fetch("pictures")
    assert_equal [ attachment.id ], pictures.map { |picture| picture.fetch("id") }
  end

  test "deletes one picture for the token owner's transaction" do
    user = create(:user)
    transaction = create_transaction(
      user: user,
      account: create_account(user: user, name: "Checking"),
      category: create_category(user: user, name: "Food", category_type: :expense),
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    transaction.pictures.attach(io: StringIO.new("receipt"), filename: "receipt.txt", content_type: "text/plain", identify: false)
    attachment = transaction.pictures.attachments.sole
    blob = attachment.blob
    raw_token = issue_token(user)

    delete api_v1_transaction_picture_path(transaction, attachment), headers: json_headers(raw_token)

    assert_response :no_content
    assert_empty response.body
    assert_empty transaction.reload.pictures.attachments
    assert_not ActiveStorage::Blob.exists?(blob.id)
  end

  test "does not list another user's transaction pictures" do
    user = create(:user)
    other_user = create(:user)
    transaction = create_transaction(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Food", category_type: :expense),
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Other Lunch"
    )
    transaction.pictures.attach(io: StringIO.new("receipt"), filename: "receipt.txt", content_type: "text/plain", identify: false)
    raw_token = issue_token(user)

    get api_v1_transaction_pictures_path(transaction), headers: json_headers(raw_token)

    assert_response :not_found
    assert_predicate transaction.reload.pictures, :attached?
  end

  test "updates a transaction for the token owner" do
    user = create(:user)
    old_account = create_account(user: user, name: "Checking", balance_cents: 3_750)
    new_account = create_account(user: user, name: "Savings", balance_cents: 10_000)
    old_category = create_category(user: user, name: "Food", category_type: :expense)
    new_category = create_category(user: user, name: "Travel", category_type: :expense)
    old_tag = create_tag(user: user, name: "Old")
    new_tag = create_tag(user: user, name: "New")
    transaction = create_transaction(
      user: user,
      account: old_account,
      category: old_category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch",
      tags: [ old_tag ]
    )
    transaction.pictures.attach(io: StringIO.new("receipt"), filename: "receipt.txt", content_type: "text/plain", identify: false)
    raw_token = issue_token(user)

    patch api_v1_transaction_path(transaction),
      params: {
        transaction: {
          transaction_kind: "expense",
          account_id: new_account.to_param,
          transaction_category_id: new_category.to_param,
          transacted_at: "2026-05-04 13:00:00",
          timezone_utc_offset_minutes: "0",
          source_amount_cents: "2000",
          destination_amount_cents: "0",
          hide_amount: "true",
          comment: "Flight",
          geo_location: { latitude: "37.7749", longitude: "-122.4194" },
          transaction_tag_ids: [ new_tag.to_param ]
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :success
    assert_equal 5_000, old_account.reload.balance_cents
    assert_equal 8_000, new_account.reload.balance_cents
    assert_equal [ new_tag ], transaction.reload.transaction_tags.to_a
    assert_predicate transaction.pictures, :attached?

    transaction_json = JSON.parse(response.body).fetch("transaction")
    assert_equal transaction.to_param, transaction_json.fetch("id")
    assert_equal new_account.to_param, transaction_json.fetch("account_id")
    assert_equal new_category.to_param, transaction_json.fetch("transaction_category_id")
    assert_equal 2_000, transaction_json.fetch("source_amount_cents")
    assert_equal true, transaction_json.fetch("hide_amount")
    assert_equal "Flight", transaction_json.fetch("comment")
    assert_equal({ "latitude" => "37.7749", "longitude" => "-122.4194" }, transaction_json.fetch("geo_location"))
    assert_equal [ new_tag.to_param ], transaction_json.fetch("transaction_tag_ids")
    refute_includes transaction_json.keys, "user_id"
  end

  test "does not update another user's transaction" do
    user = create(:user)
    other_user = create(:user)
    other_account = create_account(user: other_user, name: "Other Checking", balance_cents: 3_750)
    other_category = create_category(user: other_user, name: "Other Food", category_type: :expense)
    transaction = create_transaction(
      user: other_user,
      account: other_account,
      category: other_category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Other Lunch"
    )
    raw_token = issue_token(user)

    patch api_v1_transaction_path(transaction),
      params: {
        transaction: {
          transaction_kind: "expense",
          account_id: other_account.to_param,
          transaction_category_id: other_category.to_param,
          transacted_at: "2026-05-04 13:00:00",
          timezone_utc_offset_minutes: "0",
          source_amount_cents: "2000",
          destination_amount_cents: "0",
          hide_amount: "false",
          comment: "Changed"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_equal "Other Lunch", transaction.reload.comment
    assert_equal 3_750, other_account.reload.balance_cents
  end

  test "batch deletes transactions for the token owner" do
    user = create(:user)
    account = create_account(user: user, name: "Checking", balance_cents: 10_750)
    income_category = create_category(user: user, name: "Salary", category_type: :income)
    expense_category = create_category(user: user, name: "Food", category_type: :expense)
    income = create_transaction(
      user: user,
      account: account,
      category: income_category,
      transaction_kind: :income,
      transacted_at: Time.zone.parse("2026-05-03 11:00:00"),
      source_amount_cents: 2_000,
      comment: "Paycheck"
    )
    expense = create_transaction(
      user: user,
      account: account,
      category: expense_category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    raw_token = issue_token(user)

    post batch_delete_api_v1_transactions_path,
      params: { transaction_ids: [ income.to_param, expense.to_param ] },
      headers: json_headers(raw_token),
      as: :json

    assert_response :no_content
    assert_empty response.body
    assert_predicate income.reload, :discarded?
    assert_predicate expense.reload, :discarded?
    assert_equal 10_000, account.reload.balance_cents
  end

  test "does not batch delete when one transaction is unavailable" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking", balance_cents: 3_750)
    category = create_category(user: user, name: "Food", category_type: :expense)
    transaction = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    other_transaction = create_transaction(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking", balance_cents: 8_000),
      category: create_category(user: other_user, name: "Other Food", category_type: :expense),
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 500,
      comment: "Other Lunch"
    )
    raw_token = issue_token(user)

    post batch_delete_api_v1_transactions_path,
      params: { transaction_ids: [ transaction.to_param, other_transaction.to_param ] },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    refute_predicate transaction.reload, :discarded?
    refute_predicate other_transaction.reload, :discarded?
    assert_equal 3_750, account.reload.balance_cents
  end

  test "batch updates transaction categories for the token owner" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    old_category = create_category(user: user, name: "Food", category_type: :expense)
    new_category = create_category(user: user, name: "Travel", category_type: :expense)
    lunch = create_transaction(
      user: user,
      account: account,
      category: old_category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    coffee = create_transaction(
      user: user,
      account: account,
      category: old_category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 13:00:00"),
      source_amount_cents: 500,
      comment: "Coffee"
    )
    raw_token = issue_token(user)

    post batch_update_category_api_v1_transactions_path,
      params: { transaction_ids: [ lunch.to_param, coffee.to_param ], transaction_category_id: new_category.to_param },
      headers: json_headers(raw_token),
      as: :json

    assert_response :no_content
    assert_empty response.body
    assert_equal new_category, lunch.reload.transaction_category
    assert_equal new_category, coffee.reload.transaction_category
  end

  test "does not batch update categories when one transaction is unavailable" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking")
    old_category = create_category(user: user, name: "Food", category_type: :expense)
    new_category = create_category(user: user, name: "Travel", category_type: :expense)
    transaction = create_transaction(
      user: user,
      account: account,
      category: old_category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    other_transaction = create_transaction(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Food", category_type: :expense),
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 500,
      comment: "Other Lunch"
    )
    raw_token = issue_token(user)

    post batch_update_category_api_v1_transactions_path,
      params: { transaction_ids: [ transaction.to_param, other_transaction.to_param ], transaction_category_id: new_category.to_param },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_equal old_category, transaction.reload.transaction_category
    refute_equal new_category, other_transaction.reload.transaction_category
  end

  test "does not batch update categories when target category type mismatches" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    old_category = create_category(user: user, name: "Food", category_type: :expense)
    income_category = create_category(user: user, name: "Salary", category_type: :income)
    transaction = create_transaction(
      user: user,
      account: account,
      category: old_category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    raw_token = issue_token(user)

    post batch_update_category_api_v1_transactions_path,
      params: { transaction_ids: [ transaction.to_param ], transaction_category_id: income_category.to_param },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_equal old_category, transaction.reload.transaction_category
    assert_match(/Transaction category does not match transaction type/i, response.body)
  end

  test "batch updates transaction source accounts for the token owner" do
    user = create(:user)
    old_account = create_account(user: user, name: "Checking", balance_cents: 3_250)
    new_account = create_account(user: user, name: "Savings", balance_cents: 10_000)
    category = create_category(user: user, name: "Food", category_type: :expense)
    lunch = create_transaction(
      user: user,
      account: old_account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    coffee = create_transaction(
      user: user,
      account: old_account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 13:00:00"),
      source_amount_cents: 500,
      comment: "Coffee"
    )
    raw_token = issue_token(user)

    post batch_update_account_api_v1_transactions_path,
      params: { transaction_ids: [ lunch.to_param, coffee.to_param ], account_id: new_account.to_param },
      headers: json_headers(raw_token),
      as: :json

    assert_response :no_content
    assert_empty response.body
    assert_equal new_account, lunch.reload.account
    assert_equal new_account, coffee.reload.account
    assert_equal 5_000, old_account.reload.balance_cents
    assert_equal 8_250, new_account.reload.balance_cents
  end

  test "batch updates transfer destination accounts for the token owner" do
    user = create(:user)
    source = create_account(user: user, name: "Checking", balance_cents: 8_000)
    old_destination = create_account(user: user, name: "Savings", balance_cents: 7_000)
    new_destination = create_account(user: user, name: "Brokerage", balance_cents: 1_000)
    category = create_category(user: user, name: "Move", category_type: :transfer)
    transfer = create_transaction(
      user: user,
      account: source,
      destination_account: old_destination,
      category: category,
      transaction_kind: :transfer,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 2_000,
      destination_amount_cents: 2_000,
      comment: "Move"
    )
    raw_token = issue_token(user)

    post batch_update_account_api_v1_transactions_path,
      params: { transaction_ids: [ transfer.to_param ], account_id: new_destination.to_param, is_destination_account: "true" },
      headers: json_headers(raw_token),
      as: :json

    assert_response :no_content
    assert_empty response.body
    assert_equal new_destination, transfer.reload.destination_account
    assert_equal 8_000, source.reload.balance_cents
    assert_equal 5_000, old_destination.reload.balance_cents
    assert_equal 3_000, new_destination.reload.balance_cents
  end

  test "does not batch update accounts when target account is unavailable" do
    user = create(:user)
    other_user = create(:user)
    old_account = create_account(user: user, name: "Checking", balance_cents: 3_750)
    other_account = create_account(user: other_user, name: "Other Checking", balance_cents: 10_000)
    category = create_category(user: user, name: "Food", category_type: :expense)
    transaction = create_transaction(
      user: user,
      account: old_account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    raw_token = issue_token(user)

    post batch_update_account_api_v1_transactions_path,
      params: { transaction_ids: [ transaction.to_param ], account_id: other_account.to_param },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_equal old_account, transaction.reload.account
    assert_equal 3_750, old_account.reload.balance_cents
    assert_equal 10_000, other_account.reload.balance_cents
  end

  test "does not batch update accounts when one transaction is unavailable" do
    user = create(:user)
    other_user = create(:user)
    old_account = create_account(user: user, name: "Checking", balance_cents: 3_750)
    new_account = create_account(user: user, name: "Savings", balance_cents: 10_000)
    category = create_category(user: user, name: "Food", category_type: :expense)
    transaction = create_transaction(
      user: user,
      account: old_account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    other_transaction = create_transaction(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Food", category_type: :expense),
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 500,
      comment: "Other Lunch"
    )
    raw_token = issue_token(user)

    post batch_update_account_api_v1_transactions_path,
      params: { transaction_ids: [ transaction.to_param, other_transaction.to_param ], account_id: new_account.to_param },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_equal old_account, transaction.reload.account
    assert_equal 3_750, old_account.reload.balance_cents
    assert_equal 10_000, new_account.reload.balance_cents
  end

  test "batch adds tags to transactions for the token owner" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Food", category_type: :expense)
    existing_tag = create_tag(user: user, name: "Meals")
    new_tag = create_tag(user: user, name: "Business")
    lunch = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch",
      tags: [ existing_tag ]
    )
    coffee = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 13:00:00"),
      source_amount_cents: 500,
      comment: "Coffee"
    )
    raw_token = issue_token(user)

    post batch_add_tags_api_v1_transactions_path,
      params: { transaction_ids: [ lunch.to_param, coffee.to_param ], transaction_tag_ids: [ existing_tag.to_param, new_tag.to_param ] },
      headers: json_headers(raw_token),
      as: :json

    assert_response :no_content
    assert_empty response.body
    assert_equal [ existing_tag, new_tag ], lunch.reload.transaction_tags.order(:id).to_a
    assert_equal [ existing_tag, new_tag ], coffee.reload.transaction_tags.order(:id).to_a
  end

  test "does not batch add tags when one tag is unavailable" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Food", category_type: :expense)
    transaction = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    tag = create_tag(user: user, name: "Meals")
    other_tag = create_tag(user: other_user, name: "Other")
    raw_token = issue_token(user)

    post batch_add_tags_api_v1_transactions_path,
      params: { transaction_ids: [ transaction.to_param ], transaction_tag_ids: [ tag.to_param, other_tag.to_param ] },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_empty transaction.reload.transaction_tags
  end

  test "does not batch add tags when one transaction is unavailable" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Food", category_type: :expense)
    transaction = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    other_transaction = create_transaction(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Food", category_type: :expense),
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 500,
      comment: "Other Lunch"
    )
    tag = create_tag(user: user, name: "Meals")
    raw_token = issue_token(user)

    post batch_add_tags_api_v1_transactions_path,
      params: { transaction_ids: [ transaction.to_param, other_transaction.to_param ], transaction_tag_ids: [ tag.to_param ] },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_empty transaction.reload.transaction_tags
    assert_empty other_transaction.reload.transaction_tags
  end

  test "batch removes tags from transactions for the token owner" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Food", category_type: :expense)
    meals_tag = create_tag(user: user, name: "Meals")
    business_tag = create_tag(user: user, name: "Business")
    personal_tag = create_tag(user: user, name: "Personal")
    lunch = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch",
      tags: [ meals_tag, business_tag, personal_tag ]
    )
    coffee = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 13:00:00"),
      source_amount_cents: 500,
      comment: "Coffee",
      tags: [ meals_tag, personal_tag ]
    )
    raw_token = issue_token(user)

    post batch_remove_tags_api_v1_transactions_path,
      params: { transaction_ids: [ lunch.to_param, coffee.to_param ], transaction_tag_ids: [ meals_tag.to_param, business_tag.to_param ] },
      headers: json_headers(raw_token),
      as: :json

    assert_response :no_content
    assert_empty response.body
    assert_equal [ personal_tag ], lunch.reload.transaction_tags.order(:id).to_a
    assert_equal [ personal_tag ], coffee.reload.transaction_tags.order(:id).to_a
  end

  test "does not batch remove tags when one tag is unavailable" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Food", category_type: :expense)
    tag = create_tag(user: user, name: "Meals")
    other_tag = create_tag(user: other_user, name: "Other")
    transaction = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch",
      tags: [ tag ]
    )
    raw_token = issue_token(user)

    post batch_remove_tags_api_v1_transactions_path,
      params: { transaction_ids: [ transaction.to_param ], transaction_tag_ids: [ tag.to_param, other_tag.to_param ] },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_equal [ tag ], transaction.reload.transaction_tags.order(:id).to_a
  end

  test "does not batch remove tags when one transaction is unavailable" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Food", category_type: :expense)
    tag = create_tag(user: user, name: "Meals")
    transaction = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch",
      tags: [ tag ]
    )
    other_transaction = create_transaction(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Food", category_type: :expense),
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 500,
      comment: "Other Lunch"
    )
    raw_token = issue_token(user)

    post batch_remove_tags_api_v1_transactions_path,
      params: { transaction_ids: [ transaction.to_param, other_transaction.to_param ], transaction_tag_ids: [ tag.to_param ] },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_equal [ tag ], transaction.reload.transaction_tags.order(:id).to_a
  end

  test "batch clears tags from transactions for the token owner" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Food", category_type: :expense)
    meals_tag = create_tag(user: user, name: "Meals")
    business_tag = create_tag(user: user, name: "Business")
    lunch = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch",
      tags: [ meals_tag, business_tag ]
    )
    coffee = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 13:00:00"),
      source_amount_cents: 500,
      comment: "Coffee",
      tags: [ meals_tag ]
    )
    raw_token = issue_token(user)

    post batch_clear_tags_api_v1_transactions_path,
      params: { transaction_ids: [ lunch.to_param, coffee.to_param ] },
      headers: json_headers(raw_token),
      as: :json

    assert_response :no_content
    assert_empty response.body
    assert_empty lunch.reload.transaction_tags
    assert_empty coffee.reload.transaction_tags
  end

  test "does not batch clear tags when one transaction is unavailable" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Food", category_type: :expense)
    tag = create_tag(user: user, name: "Meals")
    transaction = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch",
      tags: [ tag ]
    )
    other_transaction = create_transaction(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Food", category_type: :expense),
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 500,
      comment: "Other Lunch"
    )
    raw_token = issue_token(user)

    post batch_clear_tags_api_v1_transactions_path,
      params: { transaction_ids: [ transaction.to_param, other_transaction.to_param ] },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_equal [ tag ], transaction.reload.transaction_tags.order(:id).to_a
  end

  test "deletes a transaction for the token owner" do
    user = create(:user)
    account = create_account(user: user, name: "Checking", balance_cents: 3_750)
    category = create_category(user: user, name: "Food", category_type: :expense)
    transaction = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    raw_token = issue_token(user)

    delete api_v1_transaction_path(transaction), headers: json_headers(raw_token)

    assert_response :no_content
    assert_empty response.body
    assert_predicate transaction.reload, :discarded?
    assert_equal 5_000, account.reload.balance_cents
  end

  test "does not delete another user's transaction" do
    user = create(:user)
    other_user = create(:user)
    transaction = create_transaction(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking", balance_cents: 3_750),
      category: create_category(user: other_user, name: "Other Food", category_type: :expense),
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Other Lunch"
    )
    raw_token = issue_token(user)

    delete api_v1_transaction_path(transaction), headers: json_headers(raw_token)

    assert_response :not_found
    refute_predicate transaction.reload, :discarded?
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

  def create_account(user:, name:, balance_cents: 0)
    Account.create!(
      user: user,
      name: name,
      account_category: :checking_account,
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

  def create_transaction(user:, account:, category:, transaction_kind:, transacted_at:, source_amount_cents:, comment:, destination_account: nil, destination_amount_cents: 0, tags: [], geo_latitude: nil, geo_longitude: nil)
    transaction = Transaction.create!(
      user: user,
      account: account,
      destination_account: destination_account,
      transaction_category: category,
      transaction_kind: transaction_kind,
      transacted_at: transacted_at,
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: destination_amount_cents,
      comment: comment,
      geo_latitude: geo_latitude,
      geo_longitude: geo_longitude
    )
    tags.each { |tag| TransactionTagging.create!(user: user, ledger_transaction: transaction, transaction_tag: tag) }
    transaction
  end
end
