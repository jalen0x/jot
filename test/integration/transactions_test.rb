require "test_helper"

class TransactionsTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get transactions_path

    assert_redirected_to new_user_session_path
  end

  test "lists only current user transactions" do
    user = create(:user)
    other_user = create(:user)
    transaction = create_transaction(user: user, comment: "Groceries")
    create_transaction(user: other_user, comment: "Other Groceries")

    sign_in user
    get transactions_path

    assert_response :success
    assert_select "h1", text: /transactions/i
    assert_select "li", text: /#{transaction.comment}/i
    assert_select "li", text: /10.00 USD/
    assert_select "li", text: /1000 cents/, count: 0
    assert_select "li", text: /Other Groceries/i, count: 0
    assert_select "form[action='#{transaction_path(transaction)}'][data-turbo-confirm]"
  end

  test "lists transaction dates using the signed-in user's date format" do
    user = create(:user)
    create_transaction(user: user, comment: "Groceries")
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "USD",
        locale: "en",
        date_format: "month_day_year"
      }
    }
    get transactions_path

    assert_response :success
    assert_select "li", text: /05\/03\/2026 10:00/
  end

  test "lists transaction times using the signed-in user's time format" do
    user = create(:user)
    transaction = create_transaction(user: user, comment: "Groceries")
    transaction.update!(transacted_at: Time.zone.parse("2026-05-03 13:05:00"))
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "USD",
        time_format: "twelve_hour"
      }
    }
    get transactions_path

    assert_response :success
    assert_select "li", text: /2026-05-03 01:05 PM/
  end

  test "lists transaction amounts using the signed-in user's number format" do
    user = create(:user)
    transaction = create_transaction(user: user, comment: "Groceries")
    transaction.update!(source_amount_cents: 123_456)
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "USD",
        date_format: "year_month_day",
        locale: "en",
        number_format: "decimal_comma"
      }
    }
    get transactions_path

    assert_response :success
    assert_select "li", text: /1\.234,56 USD/
  end

  test "lists transaction amounts using the signed-in user's amount color" do
    user = create(:user)
    create_transaction(user: user, comment: "Groceries")
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "USD",
        expense_amount_color: "warning"
      }
    }
    get transactions_path

    assert_response :success
    assert_select "p.text-fg-warning", text: /10.00 USD/
  end

  test "lists transaction location when present" do
    user = create(:user)
    transaction = create_transaction(user: user, comment: "Coffee")
    transaction.update!(geo_latitude: 37.7749, geo_longitude: -122.4194)

    sign_in user
    get transactions_path

    assert_response :success
    assert_select "li", text: /37\.7749, -122\.4194/
    assert_select "a[href=?][target=?][rel=?]",
      "https://www.openstreetmap.org/?mlat=37.7749&mlon=-122.4194#map=16/37.7749/-122.4194",
      "_blank",
      "noopener",
      text: "Open map"
  end

  test "lists transaction location using the signed-in user's coordinate display format" do
    user = create(:user)
    transaction = create_transaction(user: user, comment: "Coffee")
    transaction.update!(geo_latitude: 37.7749, geo_longitude: -122.4194)
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "USD",
        coordinate_display_format: "longitude_latitude_degrees_minutes_seconds"
      }
    }
    get transactions_path

    assert_response :success
    assert_select "li", text: /122 deg 25 min 9\.84 sec W, 37 deg 46 min 29\.64 sec N/
  end

  test "lists transaction pictures with remove controls" do
    user = create(:user)
    transaction = create_transaction(user: user, comment: "Groceries")
    transaction.pictures.attach(io: StringIO.new("receipt"), filename: "receipt.txt", content_type: "text/plain", identify: false)
    attachment = transaction.pictures.attachments.sole

    sign_in user
    get transactions_path

    assert_response :success
    assert_select "li", text: /receipt\.txt/i
    assert_select "form[action='#{transaction_picture_path(transaction, attachment)}'][data-turbo-confirm] button", text: /remove picture/i
  end

  test "renders pagy navigation when there are more than one page of transactions" do
    user = create(:user)
    26.times { |index| create_transaction(user: user, comment: "Transaction #{index}") }
    sign_in user

    get transactions_path

    assert_response :success
    assert_select "nav[aria-label=?]", I18n.t("pagination.label")
    assert_select "nav[aria-label=?] a[href*='page=2']", I18n.t("pagination.label")
  end

  test "preloads transaction picture attachments on the index" do
    user = create(:user)
    3.times do |index|
      transaction = create_transaction(user: user, comment: "Receipt #{index}")
      transaction.pictures.attach(io: StringIO.new("receipt #{index}"), filename: "receipt-#{index}.txt", content_type: "text/plain", identify: false)
    end
    sign_in user

    queries = sql_queries do
      get transactions_path
    end

    assert_response :success
    per_record_picture_queries = queries.grep(/active_storage_attachments.*"record_id" = \$/)
    assert_empty per_record_picture_queries, "expected no per-transaction attachment queries, got:\n#{per_record_picture_queries.join("\n")}"
  end

  test "removes one transaction picture for current user" do
    user = create(:user)
    transaction = create_transaction(user: user, comment: "Lunch")
    transaction.pictures.attach(io: StringIO.new("receipt"), filename: "receipt.txt", content_type: "text/plain", identify: false)
    attachment = transaction.pictures.attachments.sole
    blob = attachment.blob
    sign_in user

    delete transaction_picture_path(transaction, attachment)

    assert_response :see_other
    assert_redirected_to transactions_path
    assert_not_predicate transaction.reload.pictures, :attached?
    refute_predicate transaction, :discarded?
    assert_not ActiveStorage::Blob.exists?(blob.id)
  end

  test "does not remove another user's transaction picture" do
    user = create(:user)
    other_user = create(:user)
    transaction = create_transaction(user: other_user, comment: "Other Lunch")
    transaction.pictures.attach(io: StringIO.new("receipt"), filename: "receipt.txt", content_type: "text/plain", identify: false)
    attachment = transaction.pictures.attachments.sole
    sign_in user

    delete transaction_picture_path(transaction, attachment)

    assert_response :not_found
    assert_predicate transaction.reload.pictures, :attached?
  end

  test "transaction params accept decimal amount and store as integer cents" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 0)
    category = create_category(user: user, category_type: :expense)
    sign_in user

    {
      "10.50" => 1_050,
      "10"    => 1_000,
      "0.99"  =>    99
    }.each do |input, expected_cents|
      post transactions_path, params: {
        transaction: {
          transaction_kind: "expense",
          account_id: account.id.to_s,
          destination_account_id: "",
          transaction_category_id: category.id.to_s,
          transacted_at: "2026-05-03 10:00:00",
          timezone_utc_offset_minutes: "0",
          source_amount: input,
          destination_amount: "0",
          comment: "Lunch #{input}"
        }
      }

      transaction = user.transactions.find_by!(comment: "Lunch #{input}")
      assert_equal expected_cents, transaction.source_amount_cents, "input was #{input.inspect}"
    end
  end

  test "edit form pre-fills decimal amount derived from stored cents" do
    user = create(:user)
    transaction = create_transaction(user: user, comment: "Lunch", source_amount_cents: 1_050)
    sign_in user

    get edit_transaction_path(transaction)

    assert_response :success
    assert_select "input[name='transaction[source_amount]'][value='10.50']"
  end

  test "creates an expense for current user" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :expense)
    tag = create_tag(user: user, name: "Food")
    sign_in user

    post transactions_path, params: {
      transaction: {
        transaction_kind: "expense",
        account_id: account.id.to_s,
        destination_account_id: "",
        transaction_category_id: category.id.to_s,
        transacted_at: "2026-05-03 10:00:00",
        timezone_utc_offset_minutes: "0",
        source_amount_cents: "1200",
        destination_amount_cents: "0",
        hide_amount: "0",
        comment: "Lunch",
        geo_latitude: "37.7749",
        geo_longitude: "-122.4194",
        pictures: [ uploaded_receipt ],
        transaction_tag_ids: [ tag.id.to_s ]
      }
    }

    transaction = user.transactions.where(transaction_kind: :expense).sole
    assert_redirected_to transactions_path
    assert_equal "Lunch", transaction.comment
    assert_equal category, transaction.transaction_category
    assert_equal [ tag ], transaction.transaction_tags.to_a
    assert_predicate transaction.pictures, :attached?
    assert_equal [ "receipt.txt" ], transaction.pictures.map(&:filename).map(&:to_s)
    assert_equal BigDecimal("37.7749"), transaction.geo_latitude
    assert_equal BigDecimal("-122.4194"), transaction.geo_longitude
    assert_equal 3_800, account.reload.balance_cents
  end

  test "updates an expense for current user" do
    user = create(:user)
    old_account = create_account(user: user, balance_cents: 3_750, name: "Checking")
    new_account = create_account(user: user, balance_cents: 10_000, name: "Savings")
    old_category = create_category(user: user, category_type: :expense, name: "Food")
    new_category = create_category(user: user, category_type: :expense, name: "Travel")
    old_tag = create_tag(user: user, name: "Old")
    new_tag = create_tag(user: user, name: "New")
    transaction = create_transaction(
      user: user,
      account: old_account,
      category: old_category,
      comment: "Lunch",
      source_amount_cents: 1_250,
      tags: [ old_tag ]
    )
    sign_in user

    get edit_transaction_path(transaction)
    assert_response :success
    assert_select "h1", text: /edit transaction/i

    patch transaction_path(transaction), params: {
      transaction: {
        transaction_kind: "expense",
        account_id: new_account.id.to_s,
        destination_account_id: "",
        transaction_category_id: new_category.id.to_s,
        transacted_at: "2026-05-04 13:00:00",
        timezone_utc_offset_minutes: "0",
        source_amount_cents: "2000",
        destination_amount_cents: "0",
        hide_amount: "1",
        comment: "Flight",
        geo_latitude: "37.7749",
        geo_longitude: "-122.4194",
        transaction_tag_ids: [ new_tag.id.to_s ]
      }
    }

    assert_redirected_to transactions_path
    assert_equal 5_000, old_account.reload.balance_cents
    assert_equal 8_000, new_account.reload.balance_cents
    assert_equal new_account, transaction.reload.account
    assert_equal new_category, transaction.transaction_category
    assert_equal "Flight", transaction.comment
    assert_equal [ new_tag ], transaction.transaction_tags.to_a
    assert_equal BigDecimal("37.7749"), transaction.geo_latitude
    assert_equal BigDecimal("-122.4194"), transaction.geo_longitude
  end

  test "does not update another user's transaction" do
    user = create(:user)
    other_user = create(:user)
    other_account = create_account(user: other_user, balance_cents: 3_750, name: "Other Checking")
    other_category = create_category(user: other_user, category_type: :expense, name: "Other Food")
    transaction = create_transaction(
      user: other_user,
      account: other_account,
      category: other_category,
      comment: "Other Lunch",
      source_amount_cents: 1_250
    )
    sign_in user

    patch transaction_path(transaction), params: {
      transaction: {
        transaction_kind: "expense",
        account_id: other_account.id.to_s,
        destination_account_id: "",
        transaction_category_id: other_category.id.to_s,
        transacted_at: "2026-05-04 13:00:00",
        timezone_utc_offset_minutes: "0",
        source_amount_cents: "2000",
        destination_amount_cents: "0",
        hide_amount: "0",
        comment: "Changed"
      }
    }

    assert_response :not_found
    assert_equal "Other Lunch", transaction.reload.comment
    assert_equal 3_750, other_account.reload.balance_cents
  end

  test "defaults the new transaction account from the signed-in user's preference" do
    user = create(:user)
    create_account(user: user, balance_cents: 0, name: "Cash")
    savings = create_account(user: user, balance_cents: 0, name: "Savings")
    sign_in user

    patch user_preference_path, params: {
      user_preference: {
        default_currency_code: "USD",
        date_format: "year_month_day",
        locale: "en",
        default_account_id: savings.id.to_s
      }
    }
    get new_transaction_path

    assert_response :success
    assert_select "select#transaction_account_id option[selected]", text: /\ASavings/
  end

  test "deletes a transaction for current user" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 3_800)
    transaction = create_transaction(user: user, comment: "Lunch")
    transaction.update!(account: account, source_amount_cents: 1_200)
    sign_in user

    delete transaction_path(transaction)

    assert_response :see_other
    assert_redirected_to transactions_path
    assert_predicate transaction.reload, :discarded?
    assert_equal 5_000, account.reload.balance_cents
  end

  test "does not delete another user's transaction" do
    user = create(:user)
    other_user = create(:user)
    transaction = create_transaction(user: other_user, comment: "Other Lunch")
    sign_in user

    delete transaction_path(transaction)

    assert_response :not_found
    refute_predicate transaction.reload, :discarded?
  end

  private

  def sql_queries(&block)
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name].in?(%w[SCHEMA TRANSACTION])

      queries << payload[:sql]
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  def uploaded_receipt
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/receipt.txt"), "text/plain")
  end

  def create_transaction(user:, comment:, account: nil, category: nil, source_amount_cents: 1000, tags: [])
    account ||= create_account(user: user, balance_cents: 5_000)
    category ||= create_category(user: user, category_type: :expense)

    transaction = Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: 0,
      comment: comment
    )
    tags.each { |tag| TransactionTagging.create!(user: user, ledger_transaction: transaction, transaction_tag: tag) }
    transaction
  end

  def create_account(user:, balance_cents:, name: "Cash")
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

  def create_category(user:, category_type:, name: category_type.to_s.humanize)
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
