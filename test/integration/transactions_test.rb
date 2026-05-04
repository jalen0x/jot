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

  test "lists transaction location when present" do
    user = create(:user)
    transaction = create_transaction(user: user, comment: "Coffee")
    transaction.update!(geo_latitude: 37.7749, geo_longitude: -122.4194)

    sign_in user
    get transactions_path

    assert_response :success
    assert_select "li", text: /37\.7749, -122\.4194/
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
    assert_select "form[action='#{transaction_picture_path(transaction, attachment)}'] button", text: /remove picture/i
  end

  test "removes one transaction picture for current user" do
    user = create(:user)
    transaction = create_transaction(user: user, comment: "Lunch")
    transaction.pictures.attach(io: StringIO.new("receipt"), filename: "receipt.txt", content_type: "text/plain", identify: false)
    attachment = transaction.pictures.attachments.sole
    blob = attachment.blob
    sign_in user

    delete transaction_picture_path(transaction, attachment)

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
    assert_select "select#transaction_account_id option[selected]", text: "Savings"
  end

  test "deletes a transaction for current user" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 3_800)
    transaction = create_transaction(user: user, comment: "Lunch")
    transaction.update!(account: account, source_amount_cents: 1_200)
    sign_in user

    delete transaction_path(transaction)

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

  def uploaded_receipt
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/receipt.txt"), "text/plain")
  end

  def create_transaction(user:, comment:)
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :expense)

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1000,
      destination_amount_cents: 0,
      comment: comment
    )
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

  def create_category(user:, category_type:)
    TransactionCategory.create!(
      user: user,
      name: category_type.to_s.humanize,
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
