# ezBookkeeping Transaction Batch Account API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add JSON API support for moving multiple transactions to another source account, and moving transfer transactions to another destination account.

**Architecture:** Add a focused `TransactionBatchAccountUpdater` service that validates the whole batch first, then updates transaction account fields and reapplies account balances in one DB transaction. The API controller resolves all transaction and account IDs through the current user's scopes before delegating, so unavailable IDs fail with `404` before any update happens.

**Tech Stack:** Rails 8.1, Minitest integration/service tests, Pundit policy scopes, prefixed IDs, Active Record transactions.

---

## File Map

- Create `app/services/transaction_batch_account_updater.rb`: move transaction source or destination accounts and rebalance affected accounts atomically.
- Modify `app/controllers/api/v1/transactions_controller.rb`: add collection `batch_update_account` action and target account lookup.
- Modify `app/policies/transaction_policy.rb`: authorize class-level batch account updates for authenticated users.
- Modify `config/routes.rb`: add collection `POST /api/v1/transactions/batch_update_account`.
- Modify `test/integration/api/v1/transactions_test.rb`: cover source updates, destination updates, and no-partial-update behavior.
- Create `test/services/transaction_batch_account_updater_test.rb`: cover balance effects and validation at the service layer.

## Scope

In scope:
- `POST /api/v1/transactions/batch_update_account` with top-level `transaction_ids: []`, `account_id`, and optional `is_destination_account`.
- IDs may be regular numeric IDs or prefixed IDs.
- `is_destination_account` uses real HTTP string values such as `"true"`; missing or falsey values update the source account.
- If any transaction or account ID is unavailable to the token owner, return `404` and update nothing.
- Source account updates rebalance income, expense, transfer, and balance-adjustment transactions.
- Destination account updates are allowed only for transfer transactions.
- Known business-rule failures return `422 Unprocessable Content` and update nothing.
- Successful batch update returns `204 No Content`.

Out of scope:
- Legacy `.json` route alias `v1/transactions/batch_update/account.json`.
- UI controls for batch account moves.
- Transaction edit-lock/date-window parity from ezBookkeeping.

---

### Task 1: Add Failing Tests

**Files:**
- Create: `test/services/transaction_batch_account_updater_test.rb`
- Modify: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Add service tests**

Create `test/services/transaction_batch_account_updater_test.rb`:

```ruby
require "test_helper"

class TransactionBatchAccountUpdaterTest < ActiveSupport::TestCase
  test "moves source accounts and reapplies balances" do
    user = create(:user)
    old_account = create_account(user: user, name: "Checking", balance_cents: 3_250)
    new_account = create_account(user: user, name: "Savings", balance_cents: 10_000)
    category = create_category(user: user, name: "Food", category_type: :expense)
    lunch = create_transaction(user: user, account: old_account, category: category, transaction_kind: :expense, source_amount_cents: 1_250, comment: "Lunch")
    coffee = create_transaction(user: user, account: old_account, category: category, transaction_kind: :expense, source_amount_cents: 500, comment: "Coffee")

    result = TransactionBatchAccountUpdater.new.update_account(transactions: [ lunch, coffee ], account: new_account)

    assert_predicate result, :updated?
    assert_equal new_account, lunch.reload.account
    assert_equal new_account, coffee.reload.account
    assert_equal 5_000, old_account.reload.balance_cents
    assert_equal 8_250, new_account.reload.balance_cents
  end

  test "moves transfer destination accounts and reapplies balances" do
    user = create(:user)
    source = create_account(user: user, name: "Checking", balance_cents: 8_000)
    old_destination = create_account(user: user, name: "Savings", balance_cents: 7_000)
    new_destination = create_account(user: user, name: "Brokerage", balance_cents: 1_000)
    category = create_category(user: user, name: "Move", category_type: :transfer)
    transfer = create_transaction(user: user, account: source, destination_account: old_destination, category: category, transaction_kind: :transfer, source_amount_cents: 2_000, destination_amount_cents: 2_000, comment: "Move")

    result = TransactionBatchAccountUpdater.new.update_account(transactions: [ transfer ], account: new_destination, destination_account: true)

    assert_predicate result, :updated?
    assert_equal new_destination, transfer.reload.destination_account
    assert_equal 8_000, source.reload.balance_cents
    assert_equal 5_000, old_destination.reload.balance_cents
    assert_equal 3_000, new_destination.reload.balance_cents
  end

  test "rejects destination account updates for non-transfer transactions without partial updates" do
    user = create(:user)
    old_account = create_account(user: user, name: "Checking", balance_cents: 3_750)
    new_account = create_account(user: user, name: "Savings", balance_cents: 10_000)
    category = create_category(user: user, name: "Food", category_type: :expense)
    expense = create_transaction(user: user, account: old_account, category: category, transaction_kind: :expense, source_amount_cents: 1_250, comment: "Lunch")

    result = TransactionBatchAccountUpdater.new.update_account(transactions: [ expense ], account: new_account, destination_account: true)

    refute_predicate result, :updated?
    assert_includes result.transaction.errors[:destination_account], "can only be updated for transfers"
    assert_equal old_account, expense.reload.account
    assert_equal 3_750, old_account.reload.balance_cents
    assert_equal 10_000, new_account.reload.balance_cents
  end

  private

  def create_account(user:, name:, balance_cents:, currency_code: "USD")
    Account.create!(user: user, name: name, account_category: :checking_account, account_structure: :single_account, icon_key: 1, color_hex: "22C55E", currency_code: currency_code, balance_cents: balance_cents, display_order: 1)
  end

  def create_category(user:, name:, category_type:)
    TransactionCategory.create!(user: user, name: name, category_type: category_type, icon_key: 1, color_hex: "F97316", display_order: 1)
  end

  def create_transaction(user:, account:, category:, transaction_kind:, source_amount_cents:, comment:, destination_account: nil, destination_amount_cents: 0)
    Transaction.create!(user: user, account: account, destination_account: destination_account, transaction_category: category, transaction_kind: transaction_kind, transacted_at: Time.zone.parse("2026-05-03 12:00:00"), timezone_utc_offset_minutes: 0, source_amount_cents: source_amount_cents, destination_amount_cents: destination_amount_cents, comment: comment)
  end
end
```

- [ ] **Step 2: Add API source account success test**

In `test/integration/api/v1/transactions_test.rb`, add after the batch category tests:

```ruby
test "batch updates transaction source accounts for the token owner" do
  user = create(:user)
  old_account = create_account(user: user, name: "Checking", balance_cents: 3_250)
  new_account = create_account(user: user, name: "Savings", balance_cents: 10_000)
  category = create_category(user: user, name: "Food", category_type: :expense)
  lunch = create_transaction(user: user, account: old_account, category: category, transaction_kind: :expense, transacted_at: Time.zone.parse("2026-05-03 12:00:00"), source_amount_cents: 1_250, comment: "Lunch")
  coffee = create_transaction(user: user, account: old_account, category: category, transaction_kind: :expense, transacted_at: Time.zone.parse("2026-05-03 13:00:00"), source_amount_cents: 500, comment: "Coffee")
  raw_token = issue_token(user)

  post batch_update_account_api_v1_transactions_path,
    params: { transaction_ids: [ lunch.to_param, coffee.to_param ], account_id: new_account.to_param },
    headers: json_headers(raw_token),
    as: :json

  assert_response :no_content
  assert_empty response.body
  assert_equal new_account, lunch.reload.account
  assert_equal new_account, coffee.reload.account
  assert_equal 5_000, old_account.reload.balance_cents
  assert_equal 8_250, new_account.reload.balance_cents
end
```

- [ ] **Step 3: Add API destination account success test**

Add:

```ruby
test "batch updates transfer destination accounts for the token owner" do
  user = create(:user)
  source = create_account(user: user, name: "Checking", balance_cents: 8_000)
  old_destination = create_account(user: user, name: "Savings", balance_cents: 7_000)
  new_destination = create_account(user: user, name: "Brokerage", balance_cents: 1_000)
  category = create_category(user: user, name: "Move", category_type: :transfer)
  transfer = create_transaction(user: user, account: source, destination_account: old_destination, category: category, transaction_kind: :transfer, transacted_at: Time.zone.parse("2026-05-03 12:00:00"), source_amount_cents: 2_000, destination_amount_cents: 2_000, comment: "Move")
  raw_token = issue_token(user)

  post batch_update_account_api_v1_transactions_path,
    params: { transaction_ids: [ transfer.to_param ], account_id: new_destination.to_param, is_destination_account: "true" },
    headers: json_headers(raw_token),
    as: :json

  assert_response :no_content
  assert_empty response.body
  assert_equal new_destination, transfer.reload.destination_account
  assert_equal 8_000, source.reload.balance_cents
  assert_equal 5_000, old_destination.reload.balance_cents
  assert_equal 3_000, new_destination.reload.balance_cents
end
```

- [ ] **Step 4: Add unavailable account no-partial test**

Add:

```ruby
test "does not batch update accounts when target account is unavailable" do
  user = create(:user)
  other_user = create(:user)
  old_account = create_account(user: user, name: "Checking", balance_cents: 3_750)
  other_account = create_account(user: other_user, name: "Other Checking", balance_cents: 10_000)
  category = create_category(user: user, name: "Food", category_type: :expense)
  transaction = create_transaction(user: user, account: old_account, category: category, transaction_kind: :expense, transacted_at: Time.zone.parse("2026-05-03 12:00:00"), source_amount_cents: 1_250, comment: "Lunch")
  raw_token = issue_token(user)

  post batch_update_account_api_v1_transactions_path,
    params: { transaction_ids: [ transaction.to_param ], account_id: other_account.to_param },
    headers: json_headers(raw_token),
    as: :json

  assert_response :not_found
  assert_equal old_account, transaction.reload.account
  assert_equal 3_750, old_account.reload.balance_cents
  assert_equal 10_000, other_account.reload.balance_cents
end
```

- [ ] **Step 5: Add unavailable transaction no-partial test**

Add:

```ruby
test "does not batch update accounts when one transaction is unavailable" do
  user = create(:user)
  other_user = create(:user)
  old_account = create_account(user: user, name: "Checking", balance_cents: 3_750)
  new_account = create_account(user: user, name: "Savings", balance_cents: 10_000)
  category = create_category(user: user, name: "Food", category_type: :expense)
  transaction = create_transaction(user: user, account: old_account, category: category, transaction_kind: :expense, transacted_at: Time.zone.parse("2026-05-03 12:00:00"), source_amount_cents: 1_250, comment: "Lunch")
  other_transaction = create_transaction(user: other_user, account: create_account(user: other_user, name: "Other Checking"), category: create_category(user: other_user, name: "Other Food", category_type: :expense), transaction_kind: :expense, transacted_at: Time.zone.parse("2026-05-03 12:00:00"), source_amount_cents: 500, comment: "Other Lunch")
  raw_token = issue_token(user)

  post batch_update_account_api_v1_transactions_path,
    params: { transaction_ids: [ transaction.to_param, other_transaction.to_param ], account_id: new_account.to_param },
    headers: json_headers(raw_token),
    as: :json

  assert_response :not_found
  assert_equal old_account, transaction.reload.account
  assert_equal 3_750, old_account.reload.balance_cents
  assert_equal 10_000, new_account.reload.balance_cents
end
```

- [ ] **Step 6: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_batch_account_updater_test.rb test/integration/api/v1/transactions_test.rb
```

Expected: FAIL because the service and route do not exist yet.

---

### Task 2: Implement Batch Account Updater Service

**Files:**
- Create: `app/services/transaction_batch_account_updater.rb`

- [ ] **Step 1: Create service**

Create `app/services/transaction_batch_account_updater.rb`:

```ruby
class TransactionBatchAccountUpdater
  def update_account(transactions:, account:, destination_account: false)
    failed_transaction = transactions.find { |transaction| invalid_transaction?(transaction, account, destination_account) }
    return Result.new(updated: false, transaction: failed_transaction) if failed_transaction.present?

    ActiveRecord::Base.transaction do
      transactions.each do |transaction|
        destination_account ? move_destination_account(transaction, account) : move_source_account(transaction, account)
      end
    end

    Result.new(updated: true)
  end

  private

  def invalid_transaction?(transaction, account, destination_account)
    if destination_account
      validate_destination_account_update(transaction, account)
    else
      validate_source_account_update(transaction, account)
    end

    transaction.errors.any?
  end

  def validate_destination_account_update(transaction, account)
    unless transaction.transfer?
      transaction.errors.add(:destination_account, "can only be updated for transfers")
      return
    end

    transaction.errors.add(:destination_account, "must differ from source account") if transaction.account == account
    if transaction.destination_account.present? && transaction.destination_account.currency_code != account.currency_code
      transaction.errors.add(:destination_account, "must use the current destination account currency")
    end
  end

  def validate_source_account_update(transaction, account)
    transaction.errors.add(:account, "must differ from destination account") if transaction.transfer? && transaction.destination_account == account
    transaction.errors.add(:account, "must use the current account currency") if transaction.account.currency_code != account.currency_code
  end

  def move_source_account(transaction, account)
    old_account = transaction.account
    return if old_account == account

    delta_cents = source_balance_delta(transaction)
    adjust_balance(old_account, -delta_cents)
    transaction.update!(account: account)
    adjust_balance(account, delta_cents)
  end

  def move_destination_account(transaction, account)
    old_account = transaction.destination_account
    return if old_account == account

    delta_cents = transaction.destination_amount_cents
    adjust_balance(old_account, -delta_cents)
    transaction.update!(destination_account: account)
    adjust_balance(account, delta_cents)
  end

  def source_balance_delta(transaction)
    case transaction.transaction_kind
    when "balance_adjustment", "income"
      transaction.source_amount_cents
    when "expense", "transfer"
      -transaction.source_amount_cents
    end
  end

  def adjust_balance(account, delta_cents)
    account.update!(balance_cents: account.reload.balance_cents + delta_cents)
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
mise exec -- bin/rails test test/services/transaction_batch_account_updater_test.rb
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
post :batch_update_account, on: :collection
```

- [ ] **Step 2: Add policy authorization**

In `app/policies/transaction_policy.rb`, add:

```ruby
def batch_update_account? = user.present?
```

- [ ] **Step 3: Add controller action and helpers**

In `app/controllers/api/v1/transactions_controller.rb`, add after `batch_update_category`:

```ruby
# POST /api/v1/transactions/batch_update_account
def batch_update_account
  authorize Transaction
  result = TransactionBatchAccountUpdater.new.update_account(
    transactions: batch_update_transactions,
    account: batch_update_account_target,
    destination_account: batch_update_destination_account?
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
def batch_update_account_target
  current_user.accounts.kept.find(Account.decode_prefix_id(batch_update_account_id) || batch_update_account_id)
end

def batch_update_account_id
  params[:account_id].to_s
end

def batch_update_destination_account?
  ActiveModel::Type::Boolean.new.cast(params[:is_destination_account])
end
```

Reuse `batch_update_transactions` and let `ActiveRecord::RecordNotFound` produce the existing API 404 behavior.

- [ ] **Step 4: Run focused tests**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_batch_account_updater_test.rb test/integration/api/v1/transactions_test.rb
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
mise exec -- bin/rubocop app/services/transaction_batch_account_updater.rb app/controllers/api/v1/transactions_controller.rb app/policies/transaction_policy.rb test/services/transaction_batch_account_updater_test.rb test/integration/api/v1/transactions_test.rb config/routes.rb
```

Expected: `no offenses detected`.

- [ ] **Step 3: Commit implementation**

Run:

```bash
git add app/services/transaction_batch_account_updater.rb app/controllers/api/v1/transactions_controller.rb app/policies/transaction_policy.rb config/routes.rb test/services/transaction_batch_account_updater_test.rb test/integration/api/v1/transactions_test.rb
git commit --no-gpg-sign -m "feat: add transaction batch account api"
```

- [ ] **Step 4: Merge back to main after verification**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
git status --short --branch
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-ff --no-gpg-sign feature/ezbookkeeping-transaction-batch-account-api-slice -m "Merge branch 'feature/ezbookkeeping-transaction-batch-account-api-slice'"
mise exec -- bin/rails test
```

If `git pull --ff-only` fails because the remote SSH endpoint is unavailable, keep the failure in the final report, merge locally from the verified local `main`, and run the same post-merge verification.

- [ ] **Step 5: Cleanup worktree and branch**

Run:

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/ezbookkeeping-transaction-batch-account-api-slice
git branch -d feature/ezbookkeeping-transaction-batch-account-api-slice
```

---

## Self-Review

- Spec coverage: The plan covers the selected parity slice from ezBookkeeping's `v1/transactions/batch_update/account.json`: requested transaction IDs, target account ID, source vs destination account selection, current-user scoping, no partial update for unavailable IDs, balance reapplication, and successful no-content API response.
- Placeholder scan: No placeholder markers or vague implementation steps remain.
- Type consistency: The service method is `update_account(transactions:, account:, destination_account: false)`; the controller route/action/policy use `batch_update_account`; tests use `transaction_ids`, `account_id`, and `is_destination_account` consistently with the Rails API naming style.
