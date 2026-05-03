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
      tags: [ tag ]
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

  def create_transaction(user:, account:, category:, transaction_kind:, transacted_at:, source_amount_cents:, comment:, tags: [])
    transaction = Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: transaction_kind,
      transacted_at: transacted_at,
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: 0,
      comment: comment
    )
    tags.each { |tag| TransactionTagging.create!(user: user, ledger_transaction: transaction, transaction_tag: tag) }
    transaction
  end
end
