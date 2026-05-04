# ezBookkeeping Transaction Batch Delete API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add JSON API support for deleting multiple transactions in one request while preserving the existing balance-reversal semantics.

**Architecture:** Add a small `TransactionBatchDeleter` service that wraps existing `TransactionReversal` calls in one database transaction. The API controller resolves all requested IDs through the current user's policy scope before deleting anything, so cross-user or missing IDs fail without partial deletion.

**Tech Stack:** Rails 8.1, Minitest integration/service tests, Pundit policy scopes, prefixed IDs, discard soft deletion.

---

## File Map

- Create `app/services/transaction_batch_deleter.rb`: delete multiple transactions atomically by delegating each item to `TransactionReversal`.
- Modify `app/controllers/api/v1/transactions_controller.rb`: add collection `batch_delete` action and ID resolution.
- Modify `app/policies/transaction_policy.rb`: authorize class-level batch delete for authenticated users.
- Modify `config/routes.rb`: add collection `POST /api/v1/transactions/batch_delete`.
- Modify `test/integration/api/v1/transactions_test.rb`: cover batch delete success and cross-user no-partial-delete behavior.
- Create `test/services/transaction_batch_deleter_test.rb`: cover service-level atomic balance reversal.

## Scope

In scope:
- `POST /api/v1/transactions/batch_delete` with top-level `transaction_ids: []`.
- All IDs may be regular numeric IDs or prefixed transaction IDs.
- If any ID is unavailable to the token owner, return `404` and delete nothing.
- Successful batch delete returns `204 No Content`.

Out of scope:
- Batch update of categories/accounts/tags.
- Legacy `.json` route alias `v1/transactions/batch_delete.json`.
- Asynchronous background deletion.

## Regression Risks Covered

- Multiple transaction reversals produce the same final balance as deleting each transaction individually.
- Cross-user IDs do not partially delete the caller's valid transactions.
- Discarded transactions are not accepted for batch deletion because lookup is scoped to kept records.

---

### Task 1: Add Failing Tests

**Files:**
- Create: `test/services/transaction_batch_deleter_test.rb`
- Modify: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Add service tests**

Create `test/services/transaction_batch_deleter_test.rb`:

```ruby
require "test_helper"

class TransactionBatchDeleterTest < ActiveSupport::TestCase
  test "deletes multiple transactions and reverses balances" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 10_750)
    income_category = create_category(user: user, name: "Salary", category_type: :income)
    expense_category = create_category(user: user, name: "Food", category_type: :expense)
    income = create_transaction(user: user, account: account, category: income_category, transaction_kind: :income, source_amount_cents: 2_000, comment: "Paycheck")
    expense = create_transaction(user: user, account: account, category: expense_category, transaction_kind: :expense, source_amount_cents: 1_250, comment: "Lunch")

    result = TransactionBatchDeleter.new.delete_transactions(transactions: [ income, expense ])

    assert_predicate result, :deleted?
    assert_predicate income.reload, :discarded?
    assert_predicate expense.reload, :discarded?
    assert_equal 10_000, account.reload.balance_cents
  end

  private

  def create_account(user:, balance_cents: 0)
    Account.create!(
      user: user,
      name: "Checking",
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

  def create_transaction(user:, account:, category:, transaction_kind:, source_amount_cents:, comment:)
    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: transaction_kind,
      transacted_at: Time.zone.parse("2026-05-03 12:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: 0,
      comment: comment
    )
  end
end
```

- [ ] **Step 2: Add API success test**

In `test/integration/api/v1/transactions_test.rb`, add before the single delete test:

```ruby
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
```

- [ ] **Step 3: Add API no-partial-delete test**

Add:

```ruby
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
```

- [ ] **Step 4: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_batch_deleter_test.rb test/integration/api/v1/transactions_test.rb
```

Expected: FAIL because the service and route do not exist yet.

---

### Task 2: Implement Batch Deleter Service

**Files:**
- Create: `app/services/transaction_batch_deleter.rb`

- [ ] **Step 1: Create service**

Create `app/services/transaction_batch_deleter.rb`:

```ruby
class TransactionBatchDeleter
  def delete_transactions(transactions:)
    failed_transaction = nil

    ActiveRecord::Base.transaction do
      transactions.each do |transaction|
        result = TransactionReversal.new.delete_transaction(transaction: transaction)
        next if result.deleted?

        failed_transaction = result.transaction
        raise ActiveRecord::Rollback
      end
    end

    return Result.new(deleted: false, transaction: failed_transaction) if failed_transaction.present?

    Result.new(deleted: true)
  end

  class Result
    attr_reader :transaction

    def initialize(deleted:, transaction: nil)
      @deleted = deleted
      @transaction = transaction
    end

    def deleted? = @deleted
  end
end
```

- [ ] **Step 2: Run service test**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_batch_deleter_test.rb
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
post :batch_delete, on: :collection
```

- [ ] **Step 2: Add policy authorization**

In `app/policies/transaction_policy.rb`, add:

```ruby
def batch_delete? = user.present?
```

- [ ] **Step 3: Add controller action**

In `app/controllers/api/v1/transactions_controller.rb`, add after `destroy`:

```ruby
# POST /api/v1/transactions/batch_delete
def batch_delete
  authorize Transaction
  transactions = batch_delete_transactions
  result = TransactionBatchDeleter.new.delete_transactions(transactions: transactions)

  if result.deleted?
    head :no_content
  else
    render json: { errors: result.transaction.errors.full_messages }, status: :unprocessable_content
  end
end
```

Add these private methods:

```ruby
def batch_delete_transactions
  transaction_ids.map do |id|
    policy_scope(Transaction).kept.find(Transaction.decode_prefix_id(id) || id)
  end
end

def transaction_ids
  Array(params.permit(transaction_ids: [])[:transaction_ids]).reject(&:blank?).map(&:to_s).uniq
end
```

Let `ActiveRecord::RecordNotFound` produce the existing API 404 behavior.

- [ ] **Step 4: Run focused tests**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_batch_deleter_test.rb test/integration/api/v1/transactions_test.rb
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
mise exec -- bin/rubocop app/services/transaction_batch_deleter.rb app/controllers/api/v1/transactions_controller.rb app/policies/transaction_policy.rb test/services/transaction_batch_deleter_test.rb test/integration/api/v1/transactions_test.rb config/routes.rb
```

Expected: `no offenses detected`.

- [ ] **Step 3: Commit implementation**

Run:

```bash
git add app/services/transaction_batch_deleter.rb app/controllers/api/v1/transactions_controller.rb app/policies/transaction_policy.rb config/routes.rb test/services/transaction_batch_deleter_test.rb test/integration/api/v1/transactions_test.rb
git commit --no-gpg-sign -m "feat: add transaction batch delete api"
```

- [ ] **Step 4: Merge back to main after verification**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
git status --short --branch
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-ff --no-gpg-sign feature/ezbookkeeping-transaction-batch-delete-api-slice -m "Merge branch 'feature/ezbookkeeping-transaction-batch-delete-api-slice'"
mise exec -- bin/rails test
```

If `git pull --ff-only` fails because the remote SSH endpoint is unavailable, keep the failure in the final report, merge locally from the verified local `main`, and run the same post-merge verification.

- [ ] **Step 5: Cleanup worktree and branch**

Run:

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/ezbookkeeping-transaction-batch-delete-api-slice
git branch -d feature/ezbookkeeping-transaction-batch-delete-api-slice
```
