# ezBookkeeping Transaction Batch Clear Tags API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add JSON API support for clearing all tags from multiple transactions in one request.

**Architecture:** Add a focused `TransactionBatchTagClearer` service that deletes all `TransactionTagging` rows for the requested transactions inside one DB transaction. The API controller resolves all transaction IDs through the current user's policy scope before delegating, so unavailable IDs fail with `404` before any update happens.

**Tech Stack:** Rails 8.1, Minitest integration/service tests, Pundit policy scopes, prefixed IDs, Active Record transactions.

---

## File Map

- Create `app/services/transaction_batch_tag_clearer.rb`: clear all tags from multiple transactions.
- Modify `app/controllers/api/v1/transactions_controller.rb`: add collection `batch_clear_tags` action and reuse existing batch transaction lookup helper.
- Modify `app/policies/transaction_policy.rb`: authorize class-level batch tag clearing for authenticated users.
- Modify `config/routes.rb`: add collection `POST /api/v1/transactions/batch_clear_tags`.
- Modify `test/integration/api/v1/transactions_test.rb`: cover success and no-partial-update behavior.
- Create `test/services/transaction_batch_tag_clearer_test.rb`: cover service-level clearing scope.

## Scope

In scope:
- `POST /api/v1/transactions/batch_clear_tags` with top-level `transaction_ids: []`.
- Transaction IDs may be regular numeric IDs or prefixed IDs.
- If any transaction ID is unavailable to the token owner, return `404` and update nothing.
- All taggings are removed from requested transactions.
- Taggings on unrequested transactions remain attached.
- Successful batch update returns `204 No Content`.

Out of scope:
- Batch tag add/remove endpoints, already implemented.
- Batch account updates.
- Legacy `.json` route alias `v1/transactions/batch_update/tag/clear.json`.

---

### Task 1: Add Failing Tests

**Files:**
- Create: `test/services/transaction_batch_tag_clearer_test.rb`
- Modify: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Add service tests**

Create `test/services/transaction_batch_tag_clearer_test.rb`:

```ruby
require "test_helper"

class TransactionBatchTagClearerTest < ActiveSupport::TestCase
  test "clears all tags from requested transactions only" do
    user = create(:user)
    account = create_account(user: user)
    category = create_category(user: user)
    meals_tag = create_tag(user: user, name: "Meals")
    business_tag = create_tag(user: user, name: "Business")
    personal_tag = create_tag(user: user, name: "Personal")
    lunch = create_transaction(user: user, account: account, category: category, comment: "Lunch", tags: [ meals_tag, business_tag ])
    coffee = create_transaction(user: user, account: account, category: category, comment: "Coffee", tags: [ meals_tag, personal_tag ])
    decoy = create_transaction(user: user, account: account, category: category, comment: "Decoy", tags: [ personal_tag ])

    result = TransactionBatchTagClearer.new.clear_tags(transactions: [ lunch, coffee ])

    assert_predicate result, :cleared?
    assert_empty lunch.reload.transaction_tags
    assert_empty coffee.reload.transaction_tags
    assert_equal [ personal_tag ], decoy.reload.transaction_tags.order(:id).to_a
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

  def create_category(user:)
    TransactionCategory.create!(
      user: user,
      name: "Food",
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end

  def create_tag(user:, name:)
    TransactionTag.create!(user: user, name: name, display_order: 1)
  end

  def create_transaction(user:, account:, category:, comment:, tags: [])
    transaction = Transaction.create!(
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
    tags.each { |tag| TransactionTagging.create!(user: user, ledger_transaction: transaction, transaction_tag: tag) }
    transaction
  end
end
```

- [ ] **Step 2: Add API success test**

In `test/integration/api/v1/transactions_test.rb`, add after the batch remove tags tests:

```ruby
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
```

- [ ] **Step 3: Add unavailable transaction no-partial test**

Add:

```ruby
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
```

- [ ] **Step 4: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_batch_tag_clearer_test.rb test/integration/api/v1/transactions_test.rb
```

Expected: FAIL because the service and route do not exist yet.

---

### Task 2: Implement Batch Tag Clearer Service

**Files:**
- Create: `app/services/transaction_batch_tag_clearer.rb`

- [ ] **Step 1: Create service**

Create `app/services/transaction_batch_tag_clearer.rb`:

```ruby
class TransactionBatchTagClearer
  def clear_tags(transactions:)
    ActiveRecord::Base.transaction do
      TransactionTagging.where(ledger_transaction: transactions).delete_all
    end

    Result.new(cleared: true)
  end

  class Result
    def initialize(cleared:)
      @cleared = cleared
    end

    def cleared? = @cleared
  end
end
```

- [ ] **Step 2: Run service test**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_batch_tag_clearer_test.rb
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
post :batch_clear_tags, on: :collection
```

- [ ] **Step 2: Add policy authorization**

In `app/policies/transaction_policy.rb`, add:

```ruby
def batch_clear_tags? = user.present?
```

- [ ] **Step 3: Add controller action**

In `app/controllers/api/v1/transactions_controller.rb`, add after `batch_remove_tags`:

```ruby
# POST /api/v1/transactions/batch_clear_tags
def batch_clear_tags
  authorize Transaction
  TransactionBatchTagClearer.new.clear_tags(transactions: batch_update_transactions)

  head :no_content
end
```

Reuse the existing `batch_update_transactions` helper. Let `ActiveRecord::RecordNotFound` produce the existing API 404 behavior.

- [ ] **Step 4: Run focused tests**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_batch_tag_clearer_test.rb test/integration/api/v1/transactions_test.rb
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
mise exec -- bin/rubocop app/services/transaction_batch_tag_clearer.rb app/controllers/api/v1/transactions_controller.rb app/policies/transaction_policy.rb test/services/transaction_batch_tag_clearer_test.rb test/integration/api/v1/transactions_test.rb config/routes.rb
```

Expected: `no offenses detected`.

- [ ] **Step 3: Commit implementation**

Run:

```bash
git add app/services/transaction_batch_tag_clearer.rb app/controllers/api/v1/transactions_controller.rb app/policies/transaction_policy.rb config/routes.rb test/services/transaction_batch_tag_clearer_test.rb test/integration/api/v1/transactions_test.rb
git commit --no-gpg-sign -m "feat: add transaction batch clear tags api"
```

- [ ] **Step 4: Merge back to main after verification**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
git status --short --branch
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-ff --no-gpg-sign feature/ezbookkeeping-transaction-batch-clear-tags-api-slice -m "Merge branch 'feature/ezbookkeeping-transaction-batch-clear-tags-api-slice'"
mise exec -- bin/rails test
```

If `git pull --ff-only` fails because the remote SSH endpoint is unavailable, keep the failure in the final report, merge locally from the verified local `main`, and run the same post-merge verification.

- [ ] **Step 5: Cleanup worktree and branch**

Run:

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/ezbookkeeping-transaction-batch-clear-tags-api-slice
git branch -d feature/ezbookkeeping-transaction-batch-clear-tags-api-slice
```

---

## Self-Review

- Spec coverage: The plan covers the selected parity slice from ezBookkeeping's `v1/transactions/batch_update/tag/clear.json`: requested transaction IDs, current-user scoping, no partial update for unavailable transaction IDs, clearing all tags from requested transactions, preserving unrequested transactions, and successful no-content API response.
- Placeholder scan: No placeholder markers or vague implementation steps remain.
- Type consistency: The service method is `clear_tags(transactions:)`; the controller route/action/policy use `batch_clear_tags`; tests use `transaction_ids` consistently with the existing Rails API style.
