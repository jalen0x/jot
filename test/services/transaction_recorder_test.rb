require "test_helper"

class TransactionRecorderTest < ActiveSupport::TestCase
  test "records income and increases account balance" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 1_000)
    category = create_category(user: user, category_type: :income)
    tag = create_tag(user: user, name: "Payroll")

    result = TransactionRecorder.new.record_transaction(
      user: user,
      attributes: transaction_attributes(
        transaction_kind: "income",
        account_id: account.id.to_s,
        transaction_category_id: category.id.to_s,
        source_amount_cents: "2500"
      ),
      tag_ids: [ tag.id.to_s ]
    )

    assert_predicate result, :recorded?
    transaction = result.transaction
    assert_predicate transaction, :income?
    assert_equal account, transaction.account
    assert_equal category, transaction.transaction_category
    assert_equal [ tag ], transaction.transaction_tags.to_a
    assert_equal 3_500, account.reload.balance_cents
  end

  test "records expense and decreases account balance" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :expense)

    result = TransactionRecorder.new.record_transaction(
      user: user,
      attributes: transaction_attributes(
        transaction_kind: "expense",
        account_id: account.id.to_s,
        transaction_category_id: category.id.to_s,
        source_amount_cents: "1200"
      ),
      tag_ids: []
    )

    assert_predicate result, :recorded?
    assert_predicate result.transaction, :expense?
    assert_equal 3_800, account.reload.balance_cents
  end

  test "rejects records outside the user's transaction edit scope" do
    user = create(:user)
    UserPreference.create!(user: user, default_currency_code: "USD", transaction_edit_scope: "today_or_later")
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :expense)

    travel_to Time.zone.parse("2026-05-04 12:00:00") do
      result = TransactionRecorder.new.record_transaction(
        user: user,
        attributes: transaction_attributes(
          transaction_kind: "expense",
          account_id: account.id.to_s,
          transaction_category_id: category.id.to_s,
          source_amount_cents: "1200"
        ),
        tag_ids: []
      )

      refute_predicate result, :recorded?
      assert_includes result.transaction.errors[:base], "Transaction is outside the editable date range"
    end
    assert_equal 0, user.transactions.reload.count
    assert_equal 5_000, account.reload.balance_cents
  end

  test "records a transaction with prefixed tag ids" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :expense)
    tag = create_tag(user: user, name: "Meals")

    result = TransactionRecorder.new.record_transaction(
      user: user,
      attributes: transaction_attributes(
        transaction_kind: "expense",
        account_id: account.id.to_s,
        transaction_category_id: category.id.to_s,
        source_amount_cents: "1200"
      ),
      tag_ids: [ tag.to_param ]
    )

    assert_predicate result, :recorded?
    assert_equal [ tag ], result.transaction.transaction_tags.to_a
    assert_equal 3_800, account.reload.balance_cents
  end

  test "records same-currency transfer and updates both account balances" do
    user = create(:user)
    source = create_account(user: user, name: "Checking", balance_cents: 5_000)
    destination = create_account(user: user, name: "Savings", balance_cents: 1_000)
    category = create_category(user: user, category_type: :transfer)

    result = TransactionRecorder.new.record_transaction(
      user: user,
      attributes: transaction_attributes(
        transaction_kind: "transfer",
        account_id: source.id.to_s,
        destination_account_id: destination.id.to_s,
        transaction_category_id: category.id.to_s,
        source_amount_cents: "2000",
        destination_amount_cents: "2000"
      ),
      tag_ids: []
    )

    assert_predicate result, :recorded?
    assert_predicate result.transaction, :transfer?
    assert_equal destination, result.transaction.destination_account
    assert_equal 3_000, source.reload.balance_cents
    assert_equal 3_000, destination.reload.balance_cents
  end

  test "rejects same-currency transfer with different amounts" do
    user = create(:user)
    source = create_account(user: user, name: "Checking", balance_cents: 5_000)
    destination = create_account(user: user, name: "Savings", balance_cents: 1_000)
    category = create_category(user: user, category_type: :transfer)

    result = TransactionRecorder.new.record_transaction(
      user: user,
      attributes: transaction_attributes(
        transaction_kind: "transfer",
        account_id: source.id.to_s,
        destination_account_id: destination.id.to_s,
        transaction_category_id: category.id.to_s,
        source_amount_cents: "2000",
        destination_amount_cents: "1900"
      ),
      tag_ids: []
    )

    refute_predicate result, :recorded?
    assert_includes result.transaction.errors[:destination_amount_cents], "must equal source amount for same-currency transfers"
    assert_equal 5_000, source.reload.balance_cents
    assert_equal 1_000, destination.reload.balance_cents
  end

  test "rejects another user's tag" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 1_000)
    category = create_category(user: user, category_type: :expense)
    other_tag = create_tag(user: create(:user), name: "Other")

    result = TransactionRecorder.new.record_transaction(
      user: user,
      attributes: transaction_attributes(
        transaction_kind: "expense",
        account_id: account.id.to_s,
        transaction_category_id: category.id.to_s,
        source_amount_cents: "500"
      ),
      tag_ids: [ other_tag.id.to_s ]
    )

    refute_predicate result, :recorded?
    assert_includes result.transaction.errors[:transaction_tags], "include unavailable tags"
    assert_equal 1_000, account.reload.balance_cents
  end

  test "records nested geographic location" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :expense)

    result = TransactionRecorder.new.record_transaction(
      user: user,
      attributes: transaction_attributes(
        transaction_kind: "expense",
        account_id: account.id.to_s,
        transaction_category_id: category.id.to_s,
        source_amount_cents: "1200",
        geo_location: { latitude: "37.7749", longitude: "-122.4194" }
      ),
      tag_ids: []
    )

    assert_predicate result, :recorded?
    assert_equal BigDecimal("37.7749"), result.transaction.geo_latitude
    assert_equal BigDecimal("-122.4194"), result.transaction.geo_longitude
  end

  private

  def transaction_attributes(overrides)
    {
      transaction_kind: "expense",
      transacted_at: "2026-05-03 10:00:00",
      timezone_utc_offset_minutes: "0",
      source_amount_cents: "1000",
      destination_amount_cents: "0",
      hide_amount: "0",
      comment: "Recorded from Rails"
    }.merge(overrides)
  end

  def create_account(user:, name: "Cash", balance_cents: 0, currency_code: "USD")
    Account.create!(
      user: user,
      name: name,
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: currency_code,
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
