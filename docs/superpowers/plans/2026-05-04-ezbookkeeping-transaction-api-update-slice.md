# ezBookkeeping Transaction API Update Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add JSON API support for updating an existing transaction while preserving ownership boundaries, tags, pictures, optional location, and account balance correctness.

**Architecture:** Add a focused `TransactionUpdater` service that mirrors the existing `TransactionRecorder` creation seam and `TransactionReversal` balance semantics. The API controller will find a kept transaction through the current user's policy scope, authorize it, delegate all business updates to the service, and render the existing `Transaction#as_json` shape.

**Tech Stack:** Rails 8.1, Minitest service/integration tests, Pundit policy scopes, prefixed IDs, PostgreSQL-backed Active Record transactions.

---

## File Map

- Create `app/services/transaction_updater.rb`: update transaction attributes, owned associations, tags, and balances atomically.
- Modify `app/controllers/api/v1/transactions_controller.rb`: add `update` action and shared scoped lookup.
- Modify `config/routes.rb`: include `:update` for API transactions only.
- Create `test/services/transaction_updater_test.rb`: cover balance reapplication, transfer updates, tag replacement, and ownership rejection.
- Modify `test/integration/api/v1/transactions_test.rb`: cover authenticated JSON update and cross-user 404.

## Scope

In scope:
- `PATCH/PUT /api/v1/transactions/:id` with the same `transaction` parameter shape already used by create.
- Reversing the old transaction balance effect and applying the new balance effect in one DB transaction.
- Replacing taggings with the submitted `transaction_tag_ids`.
- Updating nested `geo_location` latitude/longitude.
- Leaving existing pictures untouched.

Out of scope:
- HTML edit UI.
- Batch transaction update endpoints.
- Legacy `.json` path aliases such as `v1/transactions/modify.json`.
- Picture replacement during update.
- Refactoring existing recorder/reversal balance helpers.

## Regression Risks Covered

- Updating amount/account does not double-count balances.
- Transfer updates adjust both source and destination accounts.
- Another user's account/category/tag cannot be assigned through update params.
- Another user's transaction cannot be updated.
- Existing pictures remain attached when non-picture attributes change.

---

### Task 1: Add Failing Tests

**Files:**
- Create: `test/services/transaction_updater_test.rb`
- Modify: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Add service tests**

Create `test/services/transaction_updater_test.rb`:

```ruby
require "test_helper"

class TransactionUpdaterTest < ActiveSupport::TestCase
  test "updates an expense and reapplies balances" do
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
      source_amount_cents: 1_250,
      comment: "Lunch",
      tags: [ old_tag ]
    )
    transaction.pictures.attach(io: StringIO.new("receipt"), filename: "receipt.txt", content_type: "text/plain", identify: false)

    result = TransactionUpdater.new.update_transaction(
      transaction: transaction,
      attributes: transaction_attributes(
        transaction_kind: "expense",
        account_id: new_account.to_param,
        transaction_category_id: new_category.to_param,
        source_amount_cents: "2000",
        comment: "Flight",
        geo_location: { latitude: "37.7749", longitude: "-122.4194" }
      ),
      tag_ids: [ new_tag.to_param ]
    )

    assert_predicate result, :updated?
    assert_equal 5_000, old_account.reload.balance_cents
    assert_equal 8_000, new_account.reload.balance_cents
    assert_equal new_account, transaction.reload.account
    assert_equal new_category, transaction.transaction_category
    assert_equal 2_000, transaction.source_amount_cents
    assert_equal "Flight", transaction.comment
    assert_equal BigDecimal("37.7749"), transaction.geo_latitude
    assert_equal BigDecimal("-122.4194"), transaction.geo_longitude
    assert_equal [ new_tag ], transaction.transaction_tags.to_a
    assert_predicate transaction.pictures, :attached?
  end

  test "updates a transfer and reapplies both account balances" do
    user = create(:user)
    source = create_account(user: user, name: "Checking", balance_cents: 8_000)
    destination = create_account(user: user, name: "Savings", balance_cents: 7_000)
    category = create_category(user: user, name: "Move", category_type: :transfer)
    transaction = create_transaction(
      user: user,
      account: source,
      destination_account: destination,
      category: category,
      transaction_kind: :transfer,
      source_amount_cents: 2_000,
      destination_amount_cents: 2_000,
      comment: "Old transfer"
    )

    result = TransactionUpdater.new.update_transaction(
      transaction: transaction,
      attributes: transaction_attributes(
        transaction_kind: "transfer",
        account_id: source.to_param,
        destination_account_id: destination.to_param,
        transaction_category_id: category.to_param,
        source_amount_cents: "1500",
        destination_amount_cents: "1500",
        comment: "New transfer"
      ),
      tag_ids: []
    )

    assert_predicate result, :updated?
    assert_equal 8_500, source.reload.balance_cents
    assert_equal 6_500, destination.reload.balance_cents
    assert_equal 1_500, transaction.reload.source_amount_cents
    assert_equal 1_500, transaction.destination_amount_cents
  end

  test "rejects unavailable owned records without changing balances" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking", balance_cents: 3_750)
    category = create_category(user: user, name: "Food", category_type: :expense)
    old_tag = create_tag(user: user, name: "Old")
    other_account = create_account(user: other_user, name: "Other", balance_cents: 9_000)
    other_category = create_category(user: other_user, name: "Other Food", category_type: :expense)
    other_tag = create_tag(user: other_user, name: "Other Tag")
    transaction = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      source_amount_cents: 1_250,
      comment: "Lunch",
      tags: [ old_tag ]
    )

    result = TransactionUpdater.new.update_transaction(
      transaction: transaction,
      attributes: transaction_attributes(
        account_id: other_account.to_param,
        transaction_category_id: other_category.to_param,
        source_amount_cents: "2000"
      ),
      tag_ids: [ other_tag.to_param ]
    )

    refute_predicate result, :updated?
    assert_includes transaction.errors[:account], "is unavailable"
    assert_includes transaction.errors[:transaction_category], "is unavailable"
    assert_includes transaction.errors[:transaction_tags], "include unavailable tags"
    assert_equal 3_750, account.reload.balance_cents
    assert_equal 9_000, other_account.reload.balance_cents
    assert_equal old_tag, transaction.reload.transaction_tags.sole
    assert_equal 1_250, transaction.source_amount_cents
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
      comment: "Updated from Rails"
    }.merge(overrides)
  end

  def create_account(user:, name:, balance_cents: 0, currency_code: "USD")
    Account.create!(
      user: user,
      name: name,
      account_category: :checking_account,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: currency_code,
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

  def create_transaction(user:, account:, category:, transaction_kind:, source_amount_cents:, comment:, tags: [], destination_account: nil, destination_amount_cents: 0)
    transaction = Transaction.create!(
      user: user,
      account: account,
      destination_account: destination_account,
      transaction_category: category,
      transaction_kind: transaction_kind,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: destination_amount_cents,
      comment: comment
    )
    tags.each { |tag| TransactionTagging.create!(user: user, ledger_transaction: transaction, transaction_tag: tag) }
    transaction
  end
end
```

- [ ] **Step 2: Add API update tests**

In `test/integration/api/v1/transactions_test.rb`, add these tests before the delete tests:

```ruby
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
```

- [ ] **Step 3: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_updater_test.rb test/integration/api/v1/transactions_test.rb
```

Expected: FAIL because `TransactionUpdater` is undefined and the route does not accept PATCH yet.

- [ ] **Step 4: Commit failing tests**

Do not commit RED tests separately. Keep them unstaged until the implementation passes so `main` never contains failing tests.

---

### Task 2: Implement TransactionUpdater

**Files:**
- Create: `app/services/transaction_updater.rb`

- [ ] **Step 1: Add the service**

Create `app/services/transaction_updater.rb`:

```ruby
class TransactionUpdater
  def update_transaction(transaction:, attributes:, tag_ids:)
    original_balance = balance_snapshot(transaction)
    attributes = attributes.to_h.symbolize_keys
    transaction.assign_attributes(transaction_attributes(attributes))
    tags = assign_owned_records(transaction.user, transaction, attributes, tag_ids)
    validate_business_rules(transaction)

    return Result.new(updated: false, transaction: transaction) if transaction.errors.any? || !transaction.valid?

    ActiveRecord::Base.transaction do
      reverse_balances(original_balance)
      transaction.save!
      TransactionTagging.where(ledger_transaction: transaction).delete_all
      tags.each do |tag|
        transaction.transaction_taggings.create!(user: transaction.user, transaction_tag: tag)
      end
      update_balances(transaction)
    end

    transaction.association(:transaction_tags).target = tags
    Result.new(updated: true, transaction: transaction)
  end

  private

  def transaction_attributes(attributes)
    {
      transaction_kind: attributes[:transaction_kind],
      transacted_at: attributes[:transacted_at],
      timezone_utc_offset_minutes: attributes[:timezone_utc_offset_minutes].to_i,
      source_amount_cents: attributes[:source_amount_cents].to_i,
      destination_amount_cents: attributes[:destination_amount_cents].to_i,
      hide_amount: ActiveModel::Type::Boolean.new.cast(attributes[:hide_amount]),
      comment: attributes[:comment],
      geo_latitude: coordinate_value(attributes, :latitude, :geo_latitude),
      geo_longitude: coordinate_value(attributes, :longitude, :geo_longitude)
    }
  end

  def coordinate_value(attributes, nested_key, direct_key)
    direct_value = attributes[direct_key]
    return direct_value if direct_value.present?

    geo_location = attributes[:geo_location]
    geo_location = geo_location.to_h.symbolize_keys if geo_location.respond_to?(:to_h)
    geo_location[nested_key] if geo_location.present?
  end

  def assign_owned_records(user, transaction, attributes, tag_ids)
    transaction.account = find_owned(user.accounts.kept, attributes[:account_id], transaction, :account)
    transaction.destination_account = find_owned(user.accounts.kept, attributes[:destination_account_id], transaction, :destination_account)
    transaction.transaction_category = find_owned(user.transaction_categories.kept, attributes[:transaction_category_id], transaction, :transaction_category)
    find_tags(user, tag_ids, transaction)
  end

  def find_owned(scope, id, transaction, field)
    return if id.blank?

    scope.find(decoded_id(scope, id))
  rescue ActiveRecord::RecordNotFound
    transaction.errors.add(field, "is unavailable")
    nil
  end

  def find_tags(user, tag_ids, transaction)
    requested_ids = Array(tag_ids).reject(&:blank?).map(&:to_s).uniq
    return [] if requested_ids.empty?

    tags = requested_ids.filter_map do |id|
      user.transaction_tags.kept.find(decoded_id(user.transaction_tags.kept, id))
    rescue ActiveRecord::RecordNotFound
      nil
    end
    transaction.errors.add(:transaction_tags, "include unavailable tags") if tags.size != requested_ids.size
    tags
  end

  def decoded_id(scope, id)
    scope.klass.decode_prefix_id(id) || id
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

  def balance_snapshot(transaction)
    {
      transaction_kind: transaction.transaction_kind,
      account: transaction.account,
      destination_account: transaction.destination_account,
      source_amount_cents: transaction.source_amount_cents,
      destination_amount_cents: transaction.destination_amount_cents
    }
  end

  def reverse_balances(snapshot)
    case snapshot.fetch(:transaction_kind)
    when "balance_adjustment"
      snapshot.fetch(:account).update!(balance_cents: snapshot.fetch(:account).balance_cents - snapshot.fetch(:source_amount_cents))
    when "income"
      snapshot.fetch(:account).update!(balance_cents: snapshot.fetch(:account).balance_cents - snapshot.fetch(:source_amount_cents))
    when "expense"
      snapshot.fetch(:account).update!(balance_cents: snapshot.fetch(:account).balance_cents + snapshot.fetch(:source_amount_cents))
    when "transfer"
      snapshot.fetch(:account).update!(balance_cents: snapshot.fetch(:account).balance_cents + snapshot.fetch(:source_amount_cents))
      snapshot.fetch(:destination_account).update!(balance_cents: snapshot.fetch(:destination_account).balance_cents - snapshot.fetch(:destination_amount_cents))
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

    def initialize(updated:, transaction:)
      @updated = updated
      @transaction = transaction
    end

    def updated? = @updated
  end
end
```

- [ ] **Step 2: Run service tests**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_updater_test.rb
```

Expected: PASS after the service is implemented.

---

### Task 3: Wire The API Endpoint

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/api/v1/transactions_controller.rb`

- [ ] **Step 1: Add the route**

Change the API transactions route in `config/routes.rb` from:

```ruby
resources :transactions, only: [ :index, :create, :destroy ] do
```

to:

```ruby
resources :transactions, only: [ :index, :create, :update, :destroy ] do
```

- [ ] **Step 2: Add the controller action**

In `app/controllers/api/v1/transactions_controller.rb`, add this action between `create` and `destroy`:

```ruby
# PATCH/PUT /api/v1/transactions/:id
def update
  transaction = scoped_transaction
  authorize transaction
  result = TransactionUpdater.new.update_transaction(transaction: transaction, attributes: transaction_params, tag_ids: transaction_tag_ids)

  if result.updated?
    render json: { transaction: result.transaction }
  else
    render json: { errors: result.transaction.errors.full_messages }, status: :unprocessable_content
  end
end
```

Then replace the direct lookup in `destroy`:

```ruby
transaction = policy_scope(Transaction).kept.find(params[:id])
```

with:

```ruby
transaction = scoped_transaction
```

Finally add this private method:

```ruby
def scoped_transaction
  policy_scope(Transaction).kept.find(params[:id])
end
```

- [ ] **Step 3: Run focused API tests**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_updater_test.rb test/integration/api/v1/transactions_test.rb
```

Expected: PASS.

---

### Task 4: Final Verification And Commit

**Files:**
- All files above

- [ ] **Step 1: Run full Rails tests**

Run:

```bash
mise exec -- bin/rails test
```

Expected: PASS with zero failures/errors.

- [ ] **Step 2: Run targeted RuboCop**

Run:

```bash
mise exec -- bin/rubocop app/services/transaction_updater.rb app/controllers/api/v1/transactions_controller.rb test/services/transaction_updater_test.rb test/integration/api/v1/transactions_test.rb config/routes.rb
```

Expected: `no offenses detected`.

- [ ] **Step 3: Commit implementation**

Run:

```bash
git add app/services/transaction_updater.rb app/controllers/api/v1/transactions_controller.rb config/routes.rb test/services/transaction_updater_test.rb test/integration/api/v1/transactions_test.rb
git commit --no-gpg-sign -m "feat: add transaction update api"
```

- [ ] **Step 4: Merge back to main after verification**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
git status --short --branch
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-ff --no-gpg-sign feature/ezbookkeeping-transaction-api-update-slice -m "Merge branch 'feature/ezbookkeeping-transaction-api-update-slice'"
mise exec -- bin/rails test
```

Expected: merged `main` test suite passes.

- [ ] **Step 5: Cleanup worktree and branch**

Run:

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/ezbookkeeping-transaction-api-update-slice
git branch -d feature/ezbookkeeping-transaction-api-update-slice
```
