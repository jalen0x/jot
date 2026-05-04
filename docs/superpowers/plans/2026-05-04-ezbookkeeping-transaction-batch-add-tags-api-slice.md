# ezBookkeeping Transaction Batch Add Tags API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add JSON API support for adding one or more tags to multiple transactions in one request.

**Architecture:** Add a focused `TransactionBatchTagAdder` service that creates missing `TransactionTagging` rows inside one DB transaction and leaves existing taggings untouched. The API controller resolves all transaction and tag IDs through the current user's scopes before delegating, so unavailable IDs fail without partial updates.

**Tech Stack:** Rails 8.1, Minitest integration/service tests, Pundit policy scopes, prefixed IDs, Active Record transactions.

---

## File Map

- Create `app/services/transaction_batch_tag_adder.rb`: add owned tags to multiple transactions atomically.
- Modify `app/controllers/api/v1/transactions_controller.rb`: add collection `batch_add_tags` action and target tag lookup.
- Modify `app/policies/transaction_policy.rb`: authorize class-level batch tag add for authenticated users.
- Modify `config/routes.rb`: add collection `POST /api/v1/transactions/batch_add_tags`.
- Modify `test/integration/api/v1/transactions_test.rb`: cover success and no-partial-update behavior.
- Create `test/services/transaction_batch_tag_adder_test.rb`: cover service-level idempotent tag addition.

## Scope

In scope:
- `POST /api/v1/transactions/batch_add_tags` with top-level `transaction_ids: []` and `transaction_tag_ids: []`.
- IDs may be regular numeric IDs or prefixed IDs.
- If any transaction or tag ID is unavailable to the token owner, return `404` and update nothing.
- Existing taggings are not duplicated.
- Successful batch update returns `204 No Content`.

Out of scope:
- Batch tag remove/clear endpoints.
- Batch account updates.
- Legacy `.json` route alias `v1/transactions/batch_update/tag/add.json`.

---

### Task 1: Add Failing Tests

**Files:**
- Create: `test/services/transaction_batch_tag_adder_test.rb`
- Modify: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Add service tests**

Create `test/services/transaction_batch_tag_adder_test.rb`:

```ruby
require "test_helper"

class TransactionBatchTagAdderTest < ActiveSupport::TestCase
  test "adds tags to multiple transactions without duplicating existing taggings" do
    user = create(:user)
    account = create_account(user: user)
    category = create_category(user: user)
    existing_tag = create_tag(user: user, name: "Meals")
    new_tag = create_tag(user: user, name: "Business")
    lunch = create_transaction(user: user, account: account, category: category, comment: "Lunch", tags: [ existing_tag ])
    coffee = create_transaction(user: user, account: account, category: category, comment: "Coffee")

    result = TransactionBatchTagAdder.new.add_tags(transactions: [ lunch, coffee ], tags: [ existing_tag, new_tag ])

    assert_predicate result, :added?
    assert_equal [ existing_tag, new_tag ], lunch.reload.transaction_tags.order(:id).to_a
    assert_equal [ existing_tag, new_tag ], coffee.reload.transaction_tags.order(:id).to_a
    assert_equal 4, TransactionTagging.where(transaction_tag: [ existing_tag, new_tag ]).count
  end

  private

  def create_account(user:)
    Account.create!(user: user, name: "Checking", account_category: :checking_account, account_structure: :single_account, icon_key: 1, color_hex: "22C55E", currency_code: "USD", balance_cents: 0, display_order: 1)
  end

  def create_category(user:)
    TransactionCategory.create!(user: user, name: "Food", category_type: :expense, icon_key: 1, color_hex: "F97316", display_order: 1)
  end

  def create_tag(user:, name:)
    TransactionTag.create!(user: user, name: name, display_order: 1)
  end

  def create_transaction(user:, account:, category:, comment:, tags: [])
    transaction = Transaction.create!(user: user, account: account, transaction_category: category, transaction_kind: :expense, transacted_at: Time.zone.parse("2026-05-03 12:00:00"), timezone_utc_offset_minutes: 0, source_amount_cents: 1_250, destination_amount_cents: 0, comment: comment)
    tags.each { |tag| TransactionTagging.create!(user: user, ledger_transaction: transaction, transaction_tag: tag) }
    transaction
  end
end
```

- [ ] **Step 2: Add API success test**

In `test/integration/api/v1/transactions_test.rb`, add after the batch category tests:

```ruby
test "batch adds tags to transactions for the token owner" do
  user = create(:user)
  account = create_account(user: user, name: "Checking")
  category = create_category(user: user, name: "Food", category_type: :expense)
  existing_tag = create_tag(user: user, name: "Meals")
  new_tag = create_tag(user: user, name: "Business")
  lunch = create_transaction(user: user, account: account, category: category, transaction_kind: :expense, transacted_at: Time.zone.parse("2026-05-03 12:00:00"), source_amount_cents: 1_250, comment: "Lunch", tags: [ existing_tag ])
  coffee = create_transaction(user: user, account: account, category: category, transaction_kind: :expense, transacted_at: Time.zone.parse("2026-05-03 13:00:00"), source_amount_cents: 500, comment: "Coffee")
  raw_token = issue_token(user)

  post batch_add_tags_api_v1_transactions_path,
    params: { transaction_ids: [ lunch.to_param, coffee.to_param ], transaction_tag_ids: [ existing_tag.to_param, new_tag.to_param ] },
    headers: json_headers(raw_token),
    as: :json

  assert_response :no_content
  assert_empty response.body
  assert_equal [ existing_tag, new_tag ], lunch.reload.transaction_tags.order(:id).to_a
  assert_equal [ existing_tag, new_tag ], coffee.reload.transaction_tags.order(:id).to_a
end
```

- [ ] **Step 3: Add unavailable tag no-partial test**

Add:

```ruby
test "does not batch add tags when one tag is unavailable" do
  user = create(:user)
  other_user = create(:user)
  account = create_account(user: user, name: "Checking")
  category = create_category(user: user, name: "Food", category_type: :expense)
  transaction = create_transaction(user: user, account: account, category: category, transaction_kind: :expense, transacted_at: Time.zone.parse("2026-05-03 12:00:00"), source_amount_cents: 1_250, comment: "Lunch")
  tag = create_tag(user: user, name: "Meals")
  other_tag = create_tag(user: other_user, name: "Other")
  raw_token = issue_token(user)

  post batch_add_tags_api_v1_transactions_path,
    params: { transaction_ids: [ transaction.to_param ], transaction_tag_ids: [ tag.to_param, other_tag.to_param ] },
    headers: json_headers(raw_token),
    as: :json

  assert_response :not_found
  assert_empty transaction.reload.transaction_tags
end
```

- [ ] **Step 4: Add unavailable transaction no-partial test**

Add:

```ruby
test "does not batch add tags when one transaction is unavailable" do
  user = create(:user)
  other_user = create(:user)
  account = create_account(user: user, name: "Checking")
  category = create_category(user: user, name: "Food", category_type: :expense)
  transaction = create_transaction(user: user, account: account, category: category, transaction_kind: :expense, transacted_at: Time.zone.parse("2026-05-03 12:00:00"), source_amount_cents: 1_250, comment: "Lunch")
  other_transaction = create_transaction(user: other_user, account: create_account(user: other_user, name: "Other Checking"), category: create_category(user: other_user, name: "Other Food", category_type: :expense), transaction_kind: :expense, transacted_at: Time.zone.parse("2026-05-03 12:00:00"), source_amount_cents: 500, comment: "Other Lunch")
  tag = create_tag(user: user, name: "Meals")
  raw_token = issue_token(user)

  post batch_add_tags_api_v1_transactions_path,
    params: { transaction_ids: [ transaction.to_param, other_transaction.to_param ], transaction_tag_ids: [ tag.to_param ] },
    headers: json_headers(raw_token),
    as: :json

  assert_response :not_found
  assert_empty transaction.reload.transaction_tags
  assert_empty other_transaction.reload.transaction_tags
end
```

- [ ] **Step 5: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_batch_tag_adder_test.rb test/integration/api/v1/transactions_test.rb
```

Expected: FAIL because the service and route do not exist yet.

---

### Task 2: Implement Batch Tag Adder Service

**Files:**
- Create: `app/services/transaction_batch_tag_adder.rb`

- [ ] **Step 1: Create service**

Create `app/services/transaction_batch_tag_adder.rb`:

```ruby
class TransactionBatchTagAdder
  def add_tags(transactions:, tags:)
    ActiveRecord::Base.transaction do
      transactions.each do |transaction|
        tags.each do |tag|
          TransactionTagging.find_or_create_by!(user: transaction.user, ledger_transaction: transaction, transaction_tag: tag)
        end
      end
    end

    Result.new(added: true)
  end

  class Result
    def initialize(added:)
      @added = added
    end

    def added? = @added
  end
end
```

- [ ] **Step 2: Run service test**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_batch_tag_adder_test.rb
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
post :batch_add_tags, on: :collection
```

- [ ] **Step 2: Add policy authorization**

In `app/policies/transaction_policy.rb`, add:

```ruby
def batch_add_tags? = user.present?
```

- [ ] **Step 3: Add controller action**

In `app/controllers/api/v1/transactions_controller.rb`, add after `batch_update_category`:

```ruby
# POST /api/v1/transactions/batch_add_tags
def batch_add_tags
  authorize Transaction
  TransactionBatchTagAdder.new.add_tags(transactions: batch_update_transactions, tags: batch_tags)

  head :no_content
end
```

Add these private methods:

```ruby
def batch_tags
  transaction_tag_ids.map do |id|
    current_user.transaction_tags.kept.find(TransactionTag.decode_prefix_id(id) || id)
  end
end

def transaction_tag_ids
  Array(params.permit(transaction_tag_ids: [])[:transaction_tag_ids]).reject(&:blank?).map(&:to_s).uniq
end
```

Reuse `batch_update_transactions` and let `ActiveRecord::RecordNotFound` produce the existing API 404 behavior.

- [ ] **Step 4: Run focused tests**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_batch_tag_adder_test.rb test/integration/api/v1/transactions_test.rb
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
mise exec -- bin/rubocop app/services/transaction_batch_tag_adder.rb app/controllers/api/v1/transactions_controller.rb app/policies/transaction_policy.rb test/services/transaction_batch_tag_adder_test.rb test/integration/api/v1/transactions_test.rb config/routes.rb
```

Expected: `no offenses detected`.

- [ ] **Step 3: Commit implementation**

Run:

```bash
git add app/services/transaction_batch_tag_adder.rb app/controllers/api/v1/transactions_controller.rb app/policies/transaction_policy.rb config/routes.rb test/services/transaction_batch_tag_adder_test.rb test/integration/api/v1/transactions_test.rb
git commit --no-gpg-sign -m "feat: add transaction batch add tags api"
```

- [ ] **Step 4: Merge back to main after verification**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
git status --short --branch
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-ff --no-gpg-sign feature/ezbookkeeping-transaction-batch-add-tags-api-slice -m "Merge branch 'feature/ezbookkeeping-transaction-batch-add-tags-api-slice'"
mise exec -- bin/rails test
```

If `git pull --ff-only` fails because the remote SSH endpoint is unavailable, keep the failure in the final report, merge locally from the verified local `main`, and run the same post-merge verification.

- [ ] **Step 5: Cleanup worktree and branch**

Run:

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/ezbookkeeping-transaction-batch-add-tags-api-slice
git branch -d feature/ezbookkeeping-transaction-batch-add-tags-api-slice
```
