# ezBookkeeping Transaction Recording Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Rails-native transaction recording for income, expenses, and transfers, including category/tag assignment, account balance updates, and a transaction list UI.

**Architecture:** This slice adds the missing category foreign key to `transactions`, then routes all normal transaction creation through `TransactionRecorder#record_transaction` so balance writes and taggings happen in one database transaction. `LedgerQuery#list_transactions` owns scoped listing and simple filters; controllers stay thin and only coerce HTTP params, load form collections, and render/redirect.

**Tech Stack:** Rails 8.1, PostgreSQL SQL schema, Devise, Pundit, Discard, Prefixed IDs, ViewComponent, Hotwire/Turbo, Flowbite semantic classes, Minitest, FactoryBot.

---

## File Structure

- `db/migrate/20260503110000_add_transaction_category_to_transactions.rb`: add `transaction_category_id`, indexes, and category presence constraints.
- `app/models/transaction.rb`: category association and validation.
- `app/models/transaction_category.rb`: reverse transaction association.
- `test/models/transaction_test.rb`: DB/model coverage for category rules.
- `app/services/transaction_recorder.rb`: creates income, expense, and transfer transactions plus taggings and balance updates.
- `test/services/transaction_recorder_test.rb`: service coverage for ledger effects and invalid cross-user/transfer cases.
- `app/services/ledger_query.rb`: current-user transaction list and basic filters.
- `test/services/ledger_query_test.rb`: list ordering, scoping, and tag filter coverage.
- `app/policies/transaction_policy.rb`: Pundit ownership policy/scope.
- `app/controllers/transactions_controller.rb`: index/new/create boundary.
- `app/views/transactions/index.html.erb`: scoped transaction list.
- `app/views/transactions/new.html.erb`: transaction form shell.
- `app/views/transactions/_form.html.erb`: income/expense/transfer form.
- `config/routes.rb`: canonical `resources :transactions` route.
- `app/views/layouts/application.html.erb`: signed-in Transactions nav link.
- `test/integration/transactions_test.rb`: auth, scoping, and create-flow coverage.

## Task 1: Transaction Category Relation

**Files:**
- Modify: `test/models/transaction_test.rb`
- Create: `db/migrate/20260503110000_add_transaction_category_to_transactions.rb`
- Modify: `app/models/transaction.rb`
- Modify: `app/models/transaction_category.rb`

- [ ] **Step 1: Write failing transaction category model tests**

Replace `test/models/transaction_test.rb` with:

```ruby
require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  test "transfer transactions require a destination account" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    destination_account = create_account(user: user, name: "Savings")
    category = create_category(user: user, category_type: :transfer)

    transaction = Transaction.create!(
      user: user,
      account: account,
      destination_account: destination_account,
      transaction_category: category,
      transaction_kind: :transfer,
      transacted_at: Time.zone.parse("2026-05-03 09:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1000,
      destination_amount_cents: 1000
    )

    error = assert_raises(ActiveRecord::StatementInvalid) do
      transaction.update_column(:destination_account_id, nil)
    end

    assert_match(/transactions_transfer_destination_required/i, error.message)
  end

  test "normal transactions require a category" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")

    transaction = Transaction.new(
      user: user,
      account: account,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1500,
      destination_amount_cents: 0
    )

    refute_predicate transaction, :valid?
    assert_includes transaction.errors[:transaction_category], "can't be blank"
  end

  test "database rejects a normal transaction without a category" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, category_type: :expense)

    transaction = Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 11:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1500,
      destination_amount_cents: 0
    )

    error = assert_raises(ActiveRecord::StatementInvalid) do
      transaction.update_column(:transaction_category_id, nil)
    end

    assert_match(/transactions_normal_category_required/i, error.message)
  end

  test "balance adjustments cannot have a category" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, category_type: :expense)

    transaction = Transaction.new(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :balance_adjustment,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1500,
      destination_amount_cents: 0
    )

    refute_predicate transaction, :valid?
    assert_includes transaction.errors[:transaction_category], "must be blank"
  end

  private

  def create_account(user:, name:)
    Account.create!(
      user: user,
      name: name,
      account_category: :checking_account,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "2563EB",
      currency_code: "USD",
      balance_cents: 0,
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
end
```

- [ ] **Step 2: Run model test to verify RED**

Run:

```bash
mise exec -- bin/rails test test/models/transaction_test.rb
```

Expected: FAIL with `unknown attribute 'transaction_category' for Transaction`.

- [ ] **Step 3: Add the transaction category migration**

Create `db/migrate/20260503110000_add_transaction_category_to_transactions.rb`:

```ruby
class AddTransactionCategoryToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_reference :transactions, :transaction_category, null: true, foreign_key: true, index: true, comment: "Category assigned to normal transactions"
    add_index :transactions, [ :user_id, :transaction_category_id, :transacted_at ], name: "index_transactions_on_owner_category_time"
    add_check_constraint :transactions, "transaction_kind = 1 OR transaction_category_id IS NOT NULL", name: "transactions_normal_category_required"
    add_check_constraint :transactions, "transaction_kind <> 1 OR transaction_category_id IS NULL", name: "transactions_balance_adjustment_has_no_category"
  end
end
```

- [ ] **Step 4: Run migrations**

Run:

```bash
mise exec -- bin/rails db:migrate
mise exec -- bin/rails db:migrate RAILS_ENV=test
```

Expected: both commands complete and `db/structure.sql` gains `transaction_category_id` plus the two check constraints.

- [ ] **Step 5: Add model associations and validations**

Modify `app/models/transaction.rb` so the association block includes `transaction_category`:

```ruby
  belongs_to :user
  belongs_to :account
  belongs_to :destination_account, class_name: "Account", optional: true
  belongs_to :transaction_category, optional: true
  has_many :transaction_taggings, foreign_key: :transaction_id, dependent: :restrict_with_error, inverse_of: :ledger_transaction
  has_many :transaction_tags, through: :transaction_taggings
```

Add these validations after the amount validations in `app/models/transaction.rb`:

```ruby
  validates :transaction_category, presence: true, unless: :balance_adjustment?
  validates :transaction_category, absence: true, if: :balance_adjustment?
```

Modify `app/models/transaction_category.rb` after `has_many :sub_categories`:

```ruby
  has_many :transactions, dependent: :restrict_with_error
```

- [ ] **Step 6: Run model tests to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/models/transaction_test.rb test/models/transaction_category_test.rb
```

Expected: PASS.

- [ ] **Step 7: Commit transaction category relation**

Run:

```bash
git add db/migrate/20260503110000_add_transaction_category_to_transactions.rb db/structure.sql app/models/transaction.rb app/models/transaction_category.rb test/models/transaction_test.rb
git commit -m "feat: relate transactions to categories"
```

## Task 2: Transaction Recorder Service

**Files:**
- Create: `test/services/transaction_recorder_test.rb`
- Create: `app/services/transaction_recorder.rb`

- [ ] **Step 1: Write failing recorder service tests**

Create `test/services/transaction_recorder_test.rb`:

```ruby
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
```

- [ ] **Step 2: Run recorder tests to verify RED**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_recorder_test.rb
```

Expected: FAIL with `uninitialized constant TransactionRecorder`.

- [ ] **Step 3: Implement TransactionRecorder**

Create `app/services/transaction_recorder.rb`:

```ruby
class TransactionRecorder
  def record_transaction(user:, attributes:, tag_ids:)
    transaction = user.transactions.build(transaction_attributes(attributes))
    assign_owned_records(user, transaction, attributes, tag_ids)
    validate_business_rules(transaction)

    return Result.new(recorded: false, transaction: transaction) if transaction.errors.any? || !transaction.valid?

    ActiveRecord::Base.transaction do
      transaction.save!
      transaction.transaction_taggings.create!(taggings_for(user, transaction))
      update_balances(transaction)
    end

    Result.new(recorded: true, transaction: transaction)
  end

  private

  def transaction_attributes(attributes)
    attributes = attributes.to_h.symbolize_keys

    {
      transaction_kind: attributes[:transaction_kind],
      transacted_at: attributes[:transacted_at],
      timezone_utc_offset_minutes: attributes[:timezone_utc_offset_minutes].to_i,
      source_amount_cents: attributes[:source_amount_cents].to_i,
      destination_amount_cents: attributes[:destination_amount_cents].to_i,
      hide_amount: ActiveModel::Type::Boolean.new.cast(attributes[:hide_amount]),
      comment: attributes[:comment]
    }
  end

  def assign_owned_records(user, transaction, attributes, tag_ids)
    attributes = attributes.to_h.symbolize_keys
    transaction.account = find_owned(user.accounts.kept, attributes[:account_id], transaction, :account)
    transaction.destination_account = find_owned(user.accounts.kept, attributes[:destination_account_id], transaction, :destination_account)
    transaction.transaction_category = find_owned(user.transaction_categories.kept, attributes[:transaction_category_id], transaction, :transaction_category)
    transaction.transaction_tags = find_tags(user, tag_ids, transaction)
  end

  def find_owned(scope, id, transaction, field)
    return if id.blank?

    scope.find(id)
  rescue ActiveRecord::RecordNotFound
    transaction.errors.add(field, "is unavailable")
    nil
  end

  def find_tags(user, tag_ids, transaction)
    requested_ids = Array(tag_ids).reject(&:blank?).map(&:to_s).uniq
    return [] if requested_ids.empty?

    tags = user.transaction_tags.kept.where(id: requested_ids).to_a
    transaction.errors.add(:transaction_tags, "include unavailable tags") if tags.size != requested_ids.size
    tags
  end

  def validate_business_rules(transaction)
    validate_category_type(transaction)
    validate_transfer(transaction) if transaction.transfer?
  end

  def validate_category_type(transaction)
    return if transaction.balance_adjustment? || transaction.transaction_category.blank?
    return if transaction.transaction_category.category_type == transaction.transaction_kind

    transaction.errors.add(:transaction_category, "does not match transaction type")
  end

  def validate_transfer(transaction)
    if transaction.destination_account.blank?
      transaction.errors.add(:destination_account, "can't be blank")
      return
    end

    transaction.errors.add(:destination_account, "must differ from source account") if transaction.account == transaction.destination_account

    if transaction.source_amount_cents.negative? || transaction.destination_amount_cents.negative?
      transaction.errors.add(:source_amount_cents, "must be greater than or equal to 0 for transfers")
    end

    if transaction.account&.currency_code == transaction.destination_account.currency_code && transaction.source_amount_cents != transaction.destination_amount_cents
      transaction.errors.add(:destination_amount_cents, "must equal source amount for same-currency transfers")
    end
  end

  def taggings_for(user, transaction)
    transaction.transaction_tags.map do |tag|
      { user: user, transaction_tag: tag }
    end
  end

  def update_balances(transaction)
    case transaction.transaction_kind
    when "income"
      transaction.account.update!(balance_cents: transaction.account.balance_cents + transaction.source_amount_cents)
    when "expense"
      transaction.account.update!(balance_cents: transaction.account.balance_cents - transaction.source_amount_cents)
    when "transfer"
      transaction.account.update!(balance_cents: transaction.account.balance_cents - transaction.source_amount_cents)
      transaction.destination_account.update!(balance_cents: transaction.destination_account.balance_cents + transaction.destination_amount_cents)
    end
  end

  class Result
    attr_reader :transaction

    def initialize(recorded:, transaction:)
      @recorded = recorded
      @transaction = transaction
    end

    def recorded? = @recorded
  end
end
```

- [ ] **Step 4: Run recorder tests to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_recorder_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit TransactionRecorder**

Run:

```bash
git add app/services/transaction_recorder.rb test/services/transaction_recorder_test.rb
git commit -m "feat: record ledger transactions"
```

## Task 3: Ledger Query

**Files:**
- Create: `test/services/ledger_query_test.rb`
- Create: `app/services/ledger_query.rb`

- [ ] **Step 1: Write failing query tests**

Create `test/services/ledger_query_test.rb`:

```ruby
require "test_helper"

class LedgerQueryTest < ActiveSupport::TestCase
  test "lists current user transactions newest first" do
    user = create(:user)
    other_user = create(:user)
    older = create_transaction(user: user, comment: "Older", transacted_at: Time.zone.parse("2026-05-01 10:00:00"))
    newer = create_transaction(user: user, comment: "Newer", transacted_at: Time.zone.parse("2026-05-02 10:00:00"))
    create_transaction(user: other_user, comment: "Other", transacted_at: Time.zone.parse("2026-05-03 10:00:00"))

    transactions = LedgerQuery.new.list_transactions(user: user, filters: {})

    assert_equal [ newer, older ], transactions.to_a
  end

  test "filters by tag" do
    user = create(:user)
    matching_tag = create_tag(user: user, name: "Business")
    other_tag = create_tag(user: user, name: "Personal")
    matching = create_transaction(user: user, comment: "Matching")
    other = create_transaction(user: user, comment: "Other")
    TransactionTagging.create!(user: user, ledger_transaction: matching, transaction_tag: matching_tag)
    TransactionTagging.create!(user: user, ledger_transaction: other, transaction_tag: other_tag)

    transactions = LedgerQuery.new.list_transactions(user: user, filters: { tag_id: matching_tag.id.to_s })

    assert_equal [ matching ], transactions.to_a
  end

  private

  def create_transaction(user:, comment:, transacted_at: Time.zone.parse("2026-05-03 10:00:00"))
    account = create_account(user: user)
    category = create_category(user: user)

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: transacted_at,
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1000,
      destination_amount_cents: 0,
      comment: comment
    )
  end

  def create_account(user:)
    Account.create!(
      user: user,
      name: "Cash",
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: 0,
      display_order: 1
    )
  end

  def create_category(user:)
    TransactionCategory.create!(
      user: user,
      name: "Groceries",
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end

  def create_tag(user:, name:)
    TransactionTag.create!(user: user, name: name, display_order: 1)
  end
end
```

- [ ] **Step 2: Run query tests to verify RED**

Run:

```bash
mise exec -- bin/rails test test/services/ledger_query_test.rb
```

Expected: FAIL with `uninitialized constant LedgerQuery`.

- [ ] **Step 3: Implement LedgerQuery**

Create `app/services/ledger_query.rb`:

```ruby
class LedgerQuery
  def list_transactions(user:, filters: {})
    filters = filters.to_h.symbolize_keys
    scope = user.transactions.kept.includes(:account, :destination_account, :transaction_category, :transaction_tags)
    scope = scope.where(transaction_kind: filters[:transaction_kind]) if filters[:transaction_kind].present?
    scope = scope.where(account_id: filters[:account_id]) if filters[:account_id].present?
    scope = scope.where(transaction_category_id: filters[:transaction_category_id]) if filters[:transaction_category_id].present?
    scope = scope.joins(:transaction_taggings).where(transaction_taggings: { transaction_tag_id: filters[:tag_id] }) if filters[:tag_id].present?
    scope.order(transacted_at: :desc, id: :desc).distinct
  end
end
```

- [ ] **Step 4: Run query tests to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/services/ledger_query_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit LedgerQuery**

Run:

```bash
git add app/services/ledger_query.rb test/services/ledger_query_test.rb
git commit -m "feat: query ledger transactions"
```

## Task 4: Transactions UI

**Files:**
- Create: `test/integration/transactions_test.rb`
- Create: `app/policies/transaction_policy.rb`
- Modify: `config/routes.rb`
- Create: `app/controllers/transactions_controller.rb`
- Create: `app/views/transactions/index.html.erb`
- Create: `app/views/transactions/new.html.erb`
- Create: `app/views/transactions/_form.html.erb`
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Write failing transaction integration tests**

Create `test/integration/transactions_test.rb`:

```ruby
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
    assert_select "li", text: /Other Groceries/i, count: 0
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
        transaction_tag_ids: [ tag.id.to_s ]
      }
    }

    transaction = user.transactions.where(transaction_kind: :expense).sole
    assert_redirected_to transactions_path
    assert_equal "Lunch", transaction.comment
    assert_equal category, transaction.transaction_category
    assert_equal [ tag ], transaction.transaction_tags.to_a
    assert_equal 3_800, account.reload.balance_cents
  end

  private

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
```

- [ ] **Step 2: Run integration test to verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/transactions_test.rb
```

Expected: FAIL with missing `transactions_path`.

- [ ] **Step 3: Add policy, route, and controller**

Create `app/policies/transaction_policy.rb`:

```ruby
class TransactionPolicy < ApplicationPolicy
  def index? = user.present?
  def new? = create?
  def create? = user.present?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
```

Add this route after `resources :transaction_tags` in `config/routes.rb`:

```ruby
  resources :transactions, only: [ :index, :new, :create ]
```

Create `app/controllers/transactions_controller.rb`:

```ruby
class TransactionsController < ApplicationController
  before_action :authenticate_user!

  # GET /transactions
  def index
    authorize Transaction
    @transactions = LedgerQuery.new.list_transactions(user: current_user, filters: filter_params)
  end

  # GET /transactions/new
  def new
    @transaction = current_user.transactions.build(default_transaction_attributes)
    authorize @transaction
    load_form_collections
  end

  # POST /transactions
  def create
    authorize Transaction
    result = TransactionRecorder.new.record_transaction(user: current_user, attributes: transaction_params, tag_ids: transaction_tag_ids)

    if result.recorded?
      redirect_to transactions_path, notice: "Transaction recorded."
    else
      @transaction = result.transaction
      load_form_collections
      render :new, status: :unprocessable_content
    end
  end

  private

  def filter_params
    params.permit(:transaction_kind, :account_id, :transaction_category_id, :tag_id)
  end

  def transaction_params
    params.expect(transaction: [
      :transaction_kind,
      :account_id,
      :destination_account_id,
      :transaction_category_id,
      :transacted_at,
      :timezone_utc_offset_minutes,
      :source_amount_cents,
      :destination_amount_cents,
      :hide_amount,
      :comment,
      transaction_tag_ids: []
    ])
  end

  def transaction_tag_ids
    Array(transaction_params[:transaction_tag_ids]).reject(&:blank?)
  end

  def default_transaction_attributes
    {
      transaction_kind: :expense,
      transacted_at: Time.current.change(sec: 0),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 0,
      destination_amount_cents: 0
    }
  end

  def load_form_collections
    @accounts = current_user.accounts.kept.order(:display_order, :name)
    @transaction_categories = current_user.transaction_categories.kept.order(:category_type, :display_order, :name)
    @transaction_tags = current_user.transaction_tags.kept.order(:display_order, :name)
  end
end
```

- [ ] **Step 4: Add transaction views**

Create `app/views/transactions/index.html.erb`:

```erb
<% content_for :title, "Transactions" %>

<section class="flex flex-col gap-6">
  <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <p class="text-sm font-medium uppercase tracking-wide text-body-subtle">Ledger</p>
      <h1 class="mt-1 text-3xl font-semibold tracking-tight text-heading">Transactions</h1>
      <p class="mt-2 max-w-2xl text-sm text-body">Record income, expenses, and transfers against your Rails ledger.</p>
    </div>

    <%= render(ButtonComponent.new(href: new_transaction_path)) { "New transaction" } %>
  </div>

  <% if @transactions.any? %>
    <ul class="divide-y divide-default overflow-hidden rounded-base border border-default bg-neutral-primary-soft shadow-xs">
      <% @transactions.each do |transaction| %>
        <li id="<%= dom_id(transaction) %>" class="p-5">
          <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <h2 class="text-lg font-semibold text-heading"><%= transaction.comment.presence || transaction.transaction_kind.humanize %></h2>
              <p class="mt-1 text-sm text-body-subtle">
                <%= l(transaction.transacted_at, format: :long) %> · <%= transaction.account.name %> · <%= transaction.transaction_category.name %>
              </p>
              <% if transaction.transaction_tags.any? %>
                <div class="mt-3 flex flex-wrap gap-2">
                  <% transaction.transaction_tags.each do |tag| %>
                    <span class="rounded-base bg-neutral-secondary-medium px-3 py-1 text-sm font-medium text-heading"><%= tag.name %></span>
                  <% end %>
                </div>
              <% end %>
            </div>

            <div class="text-right">
              <p class="text-base font-semibold text-heading"><%= transaction.source_amount_cents %> cents</p>
              <p class="mt-1 text-sm text-body-subtle"><%= transaction.transaction_kind.humanize %></p>
            </div>
          </div>
        </li>
      <% end %>
    </ul>
  <% else %>
    <div class="bg-neutral-primary-soft border border-default rounded-base p-8 text-center shadow-xs">
      <h2 class="text-xl font-semibold text-heading">No transactions yet</h2>
      <p class="mx-auto mt-2 max-w-xl text-sm text-body">Create your first income, expense, or transfer after setting up accounts and categories.</p>
      <div class="mt-5"><%= render(ButtonComponent.new(href: new_transaction_path)) { "Create first transaction" } %></div>
    </div>
  <% end %>
</section>
```

Create `app/views/transactions/new.html.erb`:

```erb
<% content_for :title, "New transaction" %>

<section class="mx-auto w-full max-w-3xl">
  <div class="mb-6">
    <p class="text-sm font-medium uppercase tracking-wide text-body-subtle">Ledger</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight text-heading">New transaction</h1>
    <p class="mt-2 text-sm text-body">Record income, expenses, or transfers.</p>
  </div>

  <%= render "form", transaction: @transaction, accounts: @accounts, transaction_categories: @transaction_categories, transaction_tags: @transaction_tags %>
</section>
```

Create `app/views/transactions/_form.html.erb`:

```erb
<%# locals: (transaction:, accounts:, transaction_categories:, transaction_tags:) %>
<% field_classes = "bg-neutral-secondary-medium border border-default-medium text-heading text-sm rounded-base focus:ring-brand focus:border-brand block w-full px-3 py-2.5 shadow-xs placeholder:text-body" %>

<%= form_with model: transaction, class: "bg-neutral-primary-soft border border-default rounded-base p-6 shadow-xs" do |form| %>
  <% if transaction.errors.any? %>
    <div class="mb-5 rounded-base border border-danger bg-neutral-primary p-4 text-sm text-danger">
      <p class="font-medium">Transaction could not be recorded.</p>
      <ul class="mt-2 list-disc ps-5">
        <% transaction.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="mb-4 grid gap-4 sm:grid-cols-2">
    <div>
      <%= form.label :transaction_kind, "Type", class: "block mb-2 text-sm font-medium text-heading" %>
      <%= form.select :transaction_kind, Transaction.transaction_kinds.except("balance_adjustment").keys.map { |key| [ key.humanize, key ] }, {}, class: field_classes %>
    </div>
    <div>
      <%= form.label :transacted_at, "When", class: "block mb-2 text-sm font-medium text-heading" %>
      <%= form.datetime_field :transacted_at, required: true, class: field_classes %>
    </div>
  </div>

  <div class="mb-4 grid gap-4 sm:grid-cols-2">
    <div>
      <%= form.label :account_id, "Account", class: "block mb-2 text-sm font-medium text-heading" %>
      <%= form.collection_select :account_id, accounts, :id, :name, { prompt: "Choose account" }, required: true, class: field_classes %>
    </div>
    <div>
      <%= form.label :destination_account_id, "Destination account", class: "block mb-2 text-sm font-medium text-heading" %>
      <%= form.collection_select :destination_account_id, accounts, :id, :name, { include_blank: "Not a transfer" }, class: field_classes %>
    </div>
  </div>

  <div class="mb-4 grid gap-4 sm:grid-cols-3">
    <div>
      <%= form.label :transaction_category_id, "Category", class: "block mb-2 text-sm font-medium text-heading" %>
      <%= form.collection_select :transaction_category_id, transaction_categories, :id, :name, { prompt: "Choose category" }, required: true, class: field_classes %>
    </div>
    <%= render FormField::InputComponent.new(form: form, field: :source_amount_cents, label: "Source cents", type: :number, required: true) %>
    <%= render FormField::InputComponent.new(form: form, field: :destination_amount_cents, label: "Destination cents", type: :number) %>
  </div>

  <div class="mb-4">
    <%= form.label :transaction_tag_ids, "Tags", class: "block mb-2 text-sm font-medium text-heading" %>
    <%= form.collection_select :transaction_tag_ids, transaction_tags, :id, :name, {}, multiple: true, class: field_classes %>
  </div>

  <%= form.hidden_field :timezone_utc_offset_minutes %>
  <%= render FormField::InputComponent.new(form: form, field: :comment, label: "Comment", type: :textarea) %>

  <div class="flex items-center justify-end gap-3">
    <%= render(ButtonComponent.new(variant: :secondary, href: transactions_path)) { "Cancel" } %>
    <%= render(ButtonComponent.new(type: :submit, data: { turbo_submits_with: "Recording..." })) { "Record transaction" } %>
  </div>
<% end %>
```

- [ ] **Step 5: Add transaction navigation**

In `app/views/layouts/application.html.erb`, add this link next to the signed-in `Tags` link:

```erb
<%= link_to "Transactions", transactions_path, class: "text-sm font-medium text-body hover:text-heading" %>
```

- [ ] **Step 6: Run integration tests to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/transactions_test.rb
```

Expected: PASS.

- [ ] **Step 7: Commit transaction UI**

Run:

```bash
git add app/policies/transaction_policy.rb config/routes.rb app/controllers/transactions_controller.rb app/views/transactions app/views/layouts/application.html.erb test/integration/transactions_test.rb
git commit -m "feat: add transaction recording UI"
```

## Task 5: Slice Verification

**Files:**
- Verify: all files changed in Tasks 1-4

- [ ] **Step 1: Run targeted tests**

Run:

```bash
mise exec -- bin/rails test test/models/transaction_test.rb test/services/transaction_recorder_test.rb test/services/ledger_query_test.rb test/integration/transactions_test.rb
```

Expected: PASS.

- [ ] **Step 2: Run full test suite**

Run:

```bash
mise exec -- bin/rails test
```

Expected: PASS.

- [ ] **Step 3: Run Ruby lint**

Run:

```bash
mise exec -- bin/rubocop
```

Expected: PASS.

- [ ] **Step 4: Run ERB lint for changed views**

Run:

```bash
mise exec -- bundle exec erb_lint app/views/transactions app/views/layouts/application.html.erb
```

Expected: PASS.

- [ ] **Step 5: Commit lint-only fixes if needed**

If lint changed files, run:

```bash
git add app test config db
git commit -m "style: clean transaction recording slice"
```

Expected: commit is created only if lint produced edits.

## Self-Review Checklist

- Spec coverage: Implements the next Phase 1 seam for `TransactionRecorder`, normal transaction category assignment, transaction taggings, account balance updates, and a scoped transaction list. Dashboard, deletion/reversal, editing, advanced filters, reports, imports, settings, attachments, schedules, API, and AI remain outside this slice. MCP is excluded from the Rails rewrite scope.
- Placeholder scan: every step has concrete files, code, commands, and expected outcomes.
- Type consistency: uses `transaction_kind`, `transaction_category_id`, `source_amount_cents`, `destination_amount_cents`, `transaction_tag_ids`, and existing `ledger_transaction` tagging association consistently.
- Source alignment: Rails intentionally stores transfers as one row with `destination_account_id` rather than ezBookkeeping's paired transfer-out/transfer-in rows; account balance effects still match source rules for income, expense, and same-currency transfers.
