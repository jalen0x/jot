# ezBookkeeping Transaction Batch Category API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add JSON API support for updating the category of multiple transactions in one request.

**Architecture:** Add a focused `TransactionBatchCategoryUpdater` service that validates the target category against every transaction before saving inside one DB transaction. The API controller resolves all requested transactions and the target category through the current user's policy scope before delegating, so cross-user IDs fail without partial updates.

**Tech Stack:** Rails 8.1, Minitest integration/service tests, Pundit policy scopes, prefixed IDs, Active Record transactions.

---

## File Map

- Create `app/services/transaction_batch_category_updater.rb`: batch-assign an owned category atomically.
- Modify `app/controllers/api/v1/transactions_controller.rb`: add collection `batch_update_category` action and target category lookup.
- Modify `app/policies/transaction_policy.rb`: authorize class-level batch category update for authenticated users.
- Modify `config/routes.rb`: add collection `POST /api/v1/transactions/batch_update_category`.
- Modify `test/integration/api/v1/transactions_test.rb`: cover success, unavailable transaction no-partial-update, and category type mismatch.
- Create `test/services/transaction_batch_category_updater_test.rb`: cover service-level atomic category update.

## Scope

In scope:
- `POST /api/v1/transactions/batch_update_category` with top-level `transaction_ids: []` and `transaction_category_id`.
- IDs may be regular numeric IDs or prefixed IDs.
- If any transaction ID or target category is unavailable to the token owner, return `404` and update nothing.
- If the target category type does not match any selected transaction's kind, return `422` and update nothing.
- Successful batch update returns `204 No Content`.

Out of scope:
- Batch account updates.
- Batch tag add/remove/clear.
- Legacy `.json` route alias `v1/transactions/batch_update/category.json`.

## Regression Risks Covered

- Multiple transactions can move to a new compatible category in one request.
- Category type mismatches do not partially update earlier transactions.
- Cross-user transaction/category IDs do not partially update valid transactions.

---

### Task 1: Add Failing Tests

**Files:**
- Create: `test/services/transaction_batch_category_updater_test.rb`
- Modify: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Add service tests**

Create `test/services/transaction_batch_category_updater_test.rb`:

```ruby
require "test_helper"

class TransactionBatchCategoryUpdaterTest < ActiveSupport::TestCase
  test "updates categories for multiple transactions" do
    user = create(:user)
    account = create_account(user: user)
    old_category = create_category(user: user, name: "Food", category_type: :expense)
    new_category = create_category(user: user, name: "Travel", category_type: :expense)
    lunch = create_transaction(user: user, account: account, category: old_category, comment: "Lunch")
    coffee = create_transaction(user: user, account: account, category: old_category, comment: "Coffee")

    result = TransactionBatchCategoryUpdater.new.update_category(transactions: [ lunch, coffee ], category: new_category)

    assert_predicate result, :updated?
    assert_equal new_category, lunch.reload.transaction_category
    assert_equal new_category, coffee.reload.transaction_category
  end

  test "rejects category type mismatch without partial updates" do
    user = create(:user)
    account = create_account(user: user)
    old_category = create_category(user: user, name: "Food", category_type: :expense)
    income_category = create_category(user: user, name: "Salary", category_type: :income)
    lunch = create_transaction(user: user, account: account, category: old_category, comment: "Lunch")
    coffee = create_transaction(user: user, account: account, category: old_category, comment: "Coffee")

    result = TransactionBatchCategoryUpdater.new.update_category(transactions: [ lunch, coffee ], category: income_category)

    refute_predicate result, :updated?
    assert_includes result.transaction.errors[:transaction_category], "does not match transaction type"
    assert_equal old_category, lunch.reload.transaction_category
    assert_equal old_category, coffee.reload.transaction_category
  end

  private

  def create_account(user:)
    Account.create!(
      user: user,
      name: "Checking",
      account_category: :checking_account,
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

  def create_transaction(user:, account:, category:, comment:)
    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1_250,
      destination_amount_cents: 0,
      comment: comment
    )
  end
end
```

- [ ] **Step 2: Add API success test**

In `test/integration/api/v1/transactions_test.rb`, add after the batch delete tests:

```ruby
test "batch updates transaction categories for the token owner" do
  user = create(:user)
  account = create_account(user: user, name: "Checking")
  old_category = create_category(user: user, name: "Food", category_type: :expense)
  new_category = create_category(user: user, name: "Travel", category_type: :expense)
  lunch = create_transaction(user: user, account: account, category: old_category, transaction_kind: :expense, transacted_at: Time.zone.parse("2026-05-03 12:00:00"), source_amount_cents: 1_250, comment: "Lunch")
  coffee = create_transaction(user: user, account: account, category: old_category, transaction_kind: :expense, transacted_at: Time.zone.parse("2026-05-03 13:00:00"), source_amount_cents: 500, comment: "Coffee")
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
```

- [ ] **Step 3: Add API no-partial unavailable transaction test**

Add:

```ruby
test "does not batch update categories when one transaction is unavailable" do
  user = create(:user)
  other_user = create(:user)
  account = create_account(user: user, name: "Checking")
  old_category = create_category(user: user, name: "Food", category_type: :expense)
  new_category = create_category(user: user, name: "Travel", category_type: :expense)
  transaction = create_transaction(user: user, account: account, category: old_category, transaction_kind: :expense, transacted_at: Time.zone.parse("2026-05-03 12:00:00"), source_amount_cents: 1_250, comment: "Lunch")
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
```

- [ ] **Step 4: Add API category mismatch test**

Add:

```ruby
test "does not batch update categories when target category type mismatches" do
  user = create(:user)
  account = create_account(user: user, name: "Checking")
  old_category = create_category(user: user, name: "Food", category_type: :expense)
  income_category = create_category(user: user, name: "Salary", category_type: :income)
  transaction = create_transaction(user: user, account: account, category: old_category, transaction_kind: :expense, transacted_at: Time.zone.parse("2026-05-03 12:00:00"), source_amount_cents: 1_250, comment: "Lunch")
  raw_token = issue_token(user)

  post batch_update_category_api_v1_transactions_path,
    params: { transaction_ids: [ transaction.to_param ], transaction_category_id: income_category.to_param },
    headers: json_headers(raw_token),
    as: :json

  assert_response :unprocessable_content
  assert_equal old_category, transaction.reload.transaction_category
  assert_match(/Transaction category does not match transaction type/i, response.body)
end
```

- [ ] **Step 5: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_batch_category_updater_test.rb test/integration/api/v1/transactions_test.rb
```

Expected: FAIL because the service and route do not exist yet.

---

### Task 2: Implement Batch Category Updater Service

**Files:**
- Create: `app/services/transaction_batch_category_updater.rb`

- [ ] **Step 1: Create service**

Create `app/services/transaction_batch_category_updater.rb`:

```ruby
class TransactionBatchCategoryUpdater
  def update_category(transactions:, category:)
    failed_transaction = nil

    ActiveRecord::Base.transaction do
      transactions.each do |transaction|
        transaction.transaction_category = category
        validate_category_type(transaction)

        unless transaction.errors.empty? && transaction.save
          failed_transaction = transaction
          raise ActiveRecord::Rollback
        end
      end
    end

    return Result.new(updated: false, transaction: failed_transaction) if failed_transaction.present?

    Result.new(updated: true)
  end

  private

  def validate_category_type(transaction)
    return if transaction.balance_adjustment? || transaction.transaction_category.blank?
    return if transaction.transaction_category.category_type == transaction.transaction_kind

    transaction.errors.add(:transaction_category, "does not match transaction type")
  end

  class Result
    attr_reader :transaction

    def initialize(updated:, transaction: nil)
      @updated = updated
      @transaction = transaction
    end

    def updated? = @updated
  end
end
```

- [ ] **Step 2: Run service test**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_batch_category_updater_test.rb
```

Expected: PASS.

---

### Task 3: Wire Route, Policy, And Controller

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/policies/transaction_policy.rb`
- Modify: `app/controllers/api/v1/transactions_controller.rb`

- [ ] **Step 1: Add collection route**

In `config/routes.rb`, inside the API transactions resource block, add:

```ruby
post :batch_update_category, on: :collection
```

- [ ] **Step 2: Add policy authorization**

In `app/policies/transaction_policy.rb`, add:

```ruby
def batch_update_category? = user.present?
```

- [ ] **Step 3: Add controller action**

In `app/controllers/api/v1/transactions_controller.rb`, add after `batch_delete`:

```ruby
# POST /api/v1/transactions/batch_update_category
def batch_update_category
  authorize Transaction
  result = TransactionBatchCategoryUpdater.new.update_category(
    transactions: batch_update_transactions,
    category: batch_update_category_target
  )

  if result.updated?
    head :no_content
  else
    render json: { errors: result.transaction.errors.full_messages }, status: :unprocessable_content
  end
end
```

Add these private methods:

```ruby
def batch_update_transactions
  transaction_ids.map do |id|
    policy_scope(Transaction).kept.find(Transaction.decode_prefix_id(id) || id)
  end
end

def batch_update_category_target
  current_user.transaction_categories.kept.find(TransactionCategory.decode_prefix_id(batch_update_category_id) || batch_update_category_id)
end

def batch_update_category_id
  params[:transaction_category_id].to_s
end
```

Reuse the existing `transaction_ids` helper from batch delete. Let `ActiveRecord::RecordNotFound` produce the existing API 404 behavior.

- [ ] **Step 4: Run focused tests**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_batch_category_updater_test.rb test/integration/api/v1/transactions_test.rb
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
mise exec -- bin/rubocop app/services/transaction_batch_category_updater.rb app/controllers/api/v1/transactions_controller.rb app/policies/transaction_policy.rb test/services/transaction_batch_category_updater_test.rb test/integration/api/v1/transactions_test.rb config/routes.rb
```

Expected: `no offenses detected`.

- [ ] **Step 3: Commit implementation**

Run:

```bash
git add app/services/transaction_batch_category_updater.rb app/controllers/api/v1/transactions_controller.rb app/policies/transaction_policy.rb config/routes.rb test/services/transaction_batch_category_updater_test.rb test/integration/api/v1/transactions_test.rb
git commit --no-gpg-sign -m "feat: add transaction batch category api"
```

- [ ] **Step 4: Merge back to main after verification**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
git status --short --branch
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-ff --no-gpg-sign feature/ezbookkeeping-transaction-batch-category-api-slice -m "Merge branch 'feature/ezbookkeeping-transaction-batch-category-api-slice'"
mise exec -- bin/rails test
```

If `git pull --ff-only` fails because the remote SSH endpoint is unavailable, keep the failure in the final report, merge locally from the verified local `main`, and run the same post-merge verification.

- [ ] **Step 5: Cleanup worktree and branch**

Run:

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/ezbookkeeping-transaction-batch-category-api-slice
git branch -d feature/ezbookkeeping-transaction-batch-category-api-slice
```
