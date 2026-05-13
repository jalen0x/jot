require "test_helper"

class TransactionDrafterTest < ActiveSupport::TestCase
  # ----- Attribute coercion -----

  test "symbolizes string keys, casts amounts and timezone offset to integers" do
    user = create(:user)
    account = create_account(user: user)
    category = create_category(user: user, category_type: :expense)

    transaction = user.transactions.build
    draft = TransactionDrafter.new.draft_transaction(
      user: user,
      transaction: transaction,
      attributes: {
        "transaction_kind" => "expense",
        "transacted_at" => "2026-05-03 10:00:00",
        "timezone_utc_offset_minutes" => "-480",
        "account_id" => account.id.to_s,
        "transaction_category_id" => category.id.to_s,
        "source_amount_cents" => "1200",
        "destination_amount_cents" => "0",
        "comment" => "Lunch"
      },
      tag_ids: []
    )

    assert_predicate draft, :valid?
    assert_equal "expense", transaction.transaction_kind
    assert_equal(-480, transaction.timezone_utc_offset_minutes)
    assert_equal 1_200, transaction.source_amount_cents
    assert_equal "Lunch", transaction.comment
  end

  test "casts hide_amount strings to booleans and preserves the existing value when absent" do
    user = create(:user)
    account = create_account(user: user)
    category = create_category(user: user, category_type: :expense)

    transaction = user.transactions.build
    TransactionDrafter.new.draft_transaction(
      user: user,
      transaction: transaction,
      attributes: base_attributes(account, category).merge(hide_amount: "1"),
      tag_ids: []
    )
    assert_equal true, transaction.hide_amount

    existing = user.transactions.build(hide_amount: true)
    TransactionDrafter.new.draft_transaction(
      user: user,
      transaction: existing,
      attributes: base_attributes(account, category),
      tag_ids: []
    )
    assert_equal true, existing.hide_amount
  end

  test "reads geographic coordinates from a nested geo_location hash" do
    user = create(:user)
    account = create_account(user: user)
    category = create_category(user: user, category_type: :expense)
    transaction = user.transactions.build

    TransactionDrafter.new.draft_transaction(
      user: user,
      transaction: transaction,
      attributes: base_attributes(account, category).merge(
        geo_location: { latitude: "37.7749", longitude: "-122.4194" }
      ),
      tag_ids: []
    )

    assert_equal BigDecimal("37.7749"), transaction.geo_latitude
    assert_equal BigDecimal("-122.4194"), transaction.geo_longitude
  end

  # ----- Owner lookup -----

  test "rejects an account owned by a different user as :account is unavailable" do
    user = create(:user)
    other_account = create_account(user: create(:user))
    category = create_category(user: user, category_type: :expense)
    transaction = user.transactions.build

    draft = TransactionDrafter.new.draft_transaction(
      user: user,
      transaction: transaction,
      attributes: base_attributes(other_account, category),
      tag_ids: []
    )

    refute_predicate draft, :valid?
    assert_includes transaction.errors[:account], "is unavailable"
  end

  test "rejects a discarded category" do
    user = create(:user)
    account = create_account(user: user)
    category = create_category(user: user, category_type: :expense)
    category.discard!
    transaction = user.transactions.build

    draft = TransactionDrafter.new.draft_transaction(
      user: user,
      transaction: transaction,
      attributes: base_attributes(account, category),
      tag_ids: []
    )

    refute_predicate draft, :valid?
    assert_includes transaction.errors[:transaction_category], "is unavailable"
  end

  test "decodes prefixed account ids" do
    user = create(:user)
    account = create_account(user: user)
    category = create_category(user: user, category_type: :expense)
    transaction = user.transactions.build

    draft = TransactionDrafter.new.draft_transaction(
      user: user,
      transaction: transaction,
      attributes: base_attributes(account, category).merge(account_id: account.to_param),
      tag_ids: []
    )

    assert_predicate draft, :valid?
    assert_equal account, transaction.account
  end

  # ----- Tag resolution -----

  test "filters blank tag ids and resolves the rest" do
    user = create(:user)
    account = create_account(user: user)
    category = create_category(user: user, category_type: :expense)
    tag = create_tag(user: user, name: "Meals")
    transaction = user.transactions.build

    draft = TransactionDrafter.new.draft_transaction(
      user: user,
      transaction: transaction,
      attributes: base_attributes(account, category),
      tag_ids: [ "", nil, tag.to_param ]
    )

    assert_predicate draft, :valid?
    assert_equal [ tag ], draft.tags
    refute transaction.errors[:transaction_tags].any?
  end

  test "attaches an error when some tags are unavailable" do
    user = create(:user)
    account = create_account(user: user)
    category = create_category(user: user, category_type: :expense)
    other_tag = create_tag(user: create(:user), name: "Other")
    transaction = user.transactions.build

    draft = TransactionDrafter.new.draft_transaction(
      user: user,
      transaction: transaction,
      attributes: base_attributes(account, category),
      tag_ids: [ other_tag.to_param ]
    )

    refute_predicate draft, :valid?
    assert_includes transaction.errors[:transaction_tags], "include unavailable tags"
  end

  # ----- Business rules -----

  test "rejects a category whose type does not match the transaction kind" do
    user = create(:user)
    account = create_account(user: user)
    income_category = create_category(user: user, category_type: :income)
    transaction = user.transactions.build

    draft = TransactionDrafter.new.draft_transaction(
      user: user,
      transaction: transaction,
      attributes: base_attributes(account, income_category).merge(transaction_kind: "expense"),
      tag_ids: []
    )

    refute_predicate draft, :valid?
    assert_includes transaction.errors[:transaction_category], "does not match transaction type"
  end

  test "rejects a transfer with the same source and destination account" do
    user = create(:user)
    account = create_account(user: user)
    category = create_category(user: user, category_type: :transfer)
    transaction = user.transactions.build

    draft = TransactionDrafter.new.draft_transaction(
      user: user,
      transaction: transaction,
      attributes: base_attributes(account, category).merge(
        transaction_kind: "transfer",
        destination_account_id: account.id.to_s,
        destination_amount_cents: "1000"
      ),
      tag_ids: []
    )

    refute_predicate draft, :valid?
    assert_includes transaction.errors[:destination_account], "must differ from source account"
  end

  test "rejects a same-currency transfer with mismatched amounts" do
    user = create(:user)
    source = create_account(user: user, name: "Checking")
    destination = create_account(user: user, name: "Savings")
    category = create_category(user: user, category_type: :transfer)
    transaction = user.transactions.build

    draft = TransactionDrafter.new.draft_transaction(
      user: user,
      transaction: transaction,
      attributes: base_attributes(source, category).merge(
        transaction_kind: "transfer",
        destination_account_id: destination.id.to_s,
        source_amount_cents: "2000",
        destination_amount_cents: "1900"
      ),
      tag_ids: []
    )

    refute_predicate draft, :valid?
    assert_includes transaction.errors[:destination_amount_cents], "must equal source amount for same-currency transfers"
  end

  test "rejects a transfer with negative amounts" do
    user = create(:user)
    source = create_account(user: user, name: "Checking")
    destination = create_account(user: user, name: "Savings")
    category = create_category(user: user, category_type: :transfer)
    transaction = user.transactions.build

    draft = TransactionDrafter.new.draft_transaction(
      user: user,
      transaction: transaction,
      attributes: base_attributes(source, category).merge(
        transaction_kind: "transfer",
        destination_account_id: destination.id.to_s,
        source_amount_cents: "-100",
        destination_amount_cents: "-100"
      ),
      tag_ids: []
    )

    refute_predicate draft, :valid?
    assert_includes transaction.errors[:source_amount_cents], "must be greater than or equal to 0 for transfers"
  end

  # ----- Result.valid? semantics -----

  test "Result.valid? returns false when a manual error is attached, without invoking model validators" do
    user = create(:user)
    other_account = create_account(user: create(:user))
    category = create_category(user: user, category_type: :expense)
    transaction = user.transactions.build

    draft = TransactionDrafter.new.draft_transaction(
      user: user,
      transaction: transaction,
      attributes: base_attributes(other_account, category),
      tag_ids: []
    )

    refute_predicate draft, :valid?
    assert_includes transaction.errors[:account], "is unavailable"
  end

  test "Result.valid? runs model validators when no manual errors are present" do
    user = create(:user)
    account = create_account(user: user)
    category = create_category(user: user, category_type: :expense)
    transaction = user.transactions.build

    draft = TransactionDrafter.new.draft_transaction(
      user: user,
      transaction: transaction,
      attributes: base_attributes(account, category).merge(transacted_at: nil),
      tag_ids: []
    )

    refute_predicate draft, :valid?
    assert_includes transaction.errors[:transacted_at], "can't be blank"
  end

  private

  def base_attributes(account, category)
    {
      transaction_kind: "expense",
      transacted_at: "2026-05-03 10:00:00",
      timezone_utc_offset_minutes: "0",
      account_id: account.id.to_s,
      transaction_category_id: category.id.to_s,
      source_amount_cents: "1000",
      destination_amount_cents: "0",
      comment: "Drafted in test"
    }
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
