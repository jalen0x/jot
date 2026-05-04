# Transaction Move Between Accounts API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modern Rails API endpoint that moves all of the current user's kept transactions from one account to another.

**Architecture:** Add a Rails-native collection route, `POST /api/v1/transactions/move_between_accounts`, with snake_case JSON params and `204 No Content` success. Keep the controller thin: it authorizes the collection, scopes both account IDs through `current_user.accounts.kept`, and delegates mutation/balance work to a focused service. Do not add ezBookkeeping legacy `.json` routes, `success/result` envelopes, camelCase params, or old frontend compatibility.

**Tech Stack:** Rails 8.1, Minitest integration/service tests, Pundit, Active Record transactions.

---

## File Structure

- Create `app/services/transaction_account_mover.rb`: service that validates the move, finds all kept source/destination appearances for the current user, updates account references, and reapplies account balances atomically.
- Create `test/services/transaction_account_mover_test.rb`: service-level coverage for balance correctness, kept scoping, decoy records, and no partial update on invalid transfer moves.
- Modify `app/controllers/api/v1/transactions_controller.rb`: add `move_between_accounts` action and account lookup helpers.
- Modify `app/policies/transaction_policy.rb`: allow authenticated API users to call the collection action.
- Modify `config/routes.rb`: add the Rails-native collection route.
- Modify `test/integration/api/v1/transactions_test.rb`: cover the HTTP contract for success, unavailable accounts, and validation errors.

---

### Task 1: Service RED Tests

**Files:**
- Create: `test/services/transaction_account_mover_test.rb`

- [ ] **Step 1: Write the failing service tests**

Create `test/services/transaction_account_mover_test.rb`:

```ruby
require "test_helper"

class TransactionAccountMoverTest < ActiveSupport::TestCase
  test "moves every kept source and destination account appearance and reapplies balances" do
    user = create(:user)
    from_account = create_account(user: user, name: "Checking", balance_cents: 10_000)
    to_account = create_account(user: user, name: "Savings", balance_cents: 1_000)
    other_account = create_account(user: user, name: "Brokerage", balance_cents: 50_000)
    income_category = create_category(user: user, name: "Salary", category_type: :income)
    expense_category = create_category(user: user, name: "Food", category_type: :expense)
    transfer_category = create_category(user: user, name: "Move", category_type: :transfer)
    income = create_transaction(user: user, account: from_account, category: income_category, transaction_kind: :income, source_amount_cents: 3_000, comment: "Paycheck")
    expense = create_transaction(user: user, account: from_account, category: expense_category, transaction_kind: :expense, source_amount_cents: 1_200, comment: "Lunch")
    outgoing_transfer = create_transaction(user: user, account: from_account, destination_account: other_account, category: transfer_category, transaction_kind: :transfer, source_amount_cents: 700, destination_amount_cents: 700, comment: "Invest")
    incoming_transfer = create_transaction(user: user, account: other_account, destination_account: from_account, category: transfer_category, transaction_kind: :transfer, source_amount_cents: 2_000, destination_amount_cents: 2_000, comment: "Refund")
    decoy = create_transaction(user: user, account: other_account, category: expense_category, transaction_kind: :expense, source_amount_cents: 500, comment: "Decoy")
    discarded = create_transaction(user: user, account: from_account, category: expense_category, transaction_kind: :expense, source_amount_cents: 900, comment: "Archived")
    discarded.discard!

    result = TransactionAccountMover.new.move_between_accounts(user: user, from_account: from_account, to_account: to_account)

    assert_predicate result, :moved?
    assert_equal to_account, income.reload.account
    assert_equal to_account, expense.reload.account
    assert_equal to_account, outgoing_transfer.reload.account
    assert_equal other_account, outgoing_transfer.destination_account
    assert_equal other_account, incoming_transfer.reload.account
    assert_equal to_account, incoming_transfer.destination_account
    assert_equal other_account, decoy.reload.account
    assert_equal from_account, discarded.reload.account
    assert_equal 6_900, from_account.reload.balance_cents
    assert_equal 4_100, to_account.reload.balance_cents
    assert_equal 50_000, other_account.reload.balance_cents
  end

  test "rejects moves that would make a transfer use the same source and destination account" do
    user = create(:user)
    from_account = create_account(user: user, name: "Checking", balance_cents: 8_000)
    to_account = create_account(user: user, name: "Savings", balance_cents: 3_000)
    category = create_category(user: user, name: "Move", category_type: :transfer)
    transfer = create_transaction(user: user, account: from_account, destination_account: to_account, category: category, transaction_kind: :transfer, source_amount_cents: 2_000, destination_amount_cents: 2_000, comment: "Move")

    result = TransactionAccountMover.new.move_between_accounts(user: user, from_account: from_account, to_account: to_account)

    refute_predicate result, :moved?
    assert_includes result.errors, "Move would make a transfer use the same source and destination account"
    assert_equal from_account, transfer.reload.account
    assert_equal to_account, transfer.destination_account
    assert_equal 8_000, from_account.reload.balance_cents
    assert_equal 3_000, to_account.reload.balance_cents
  end

  private

  def create_account(user:, name:, balance_cents:, currency_code: "USD")
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
    TransactionCategory.create!(user: user, name: name, category_type: category_type, icon_key: 1, color_hex: "F97316", display_order: 1)
  end

  def create_transaction(user:, account:, category:, transaction_kind:, source_amount_cents:, comment:, destination_account: nil, destination_amount_cents: 0)
    Transaction.create!(
      user: user,
      account: account,
      destination_account: destination_account,
      transaction_category: category,
      transaction_kind: transaction_kind,
      transacted_at: Time.zone.parse("2026-05-04 12:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: destination_amount_cents,
      comment: comment
    )
  end
end
```

- [ ] **Step 2: Run the service tests and confirm RED**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_account_mover_test.rb
```

Expected: fails with `uninitialized constant TransactionAccountMover`.

---

### Task 2: Service GREEN Implementation

**Files:**
- Create: `app/services/transaction_account_mover.rb`
- Test: `test/services/transaction_account_mover_test.rb`

- [ ] **Step 1: Implement the minimal service**

Create `app/services/transaction_account_mover.rb`:

```ruby
class TransactionAccountMover
  def move_between_accounts(user:, from_account:, to_account:)
    errors = validation_errors(user, from_account, to_account)
    return Result.new(moved: false, errors: errors) if errors.any?

    source_transactions = source_transactions(user, from_account)
    destination_transactions = destination_transactions(user, from_account)
    transfer_conflict = transfer_conflict(source_transactions, destination_transactions, to_account)
    return Result.new(moved: false, errors: [ "Move would make a transfer use the same source and destination account" ]) if transfer_conflict.present?

    ActiveRecord::Base.transaction do
      source_transactions.each { |transaction| move_source_account(transaction, to_account) }
      destination_transactions.each { |transaction| move_destination_account(transaction, to_account) }
    end

    Result.new(moved: true)
  end

  private

  def validation_errors(user, from_account, to_account)
    errors = []
    errors << "From account must differ from to account" if from_account == to_account
    errors << "Accounts must use the same currency" if from_account.currency_code != to_account.currency_code
    errors << "Accounts must belong to the same user" if from_account.user_id != user.id || to_account.user_id != user.id
    errors
  end

  def source_transactions(user, from_account)
    user.transactions.kept.where(account: from_account).to_a
  end

  def destination_transactions(user, from_account)
    user.transactions.kept.transfer.where(destination_account: from_account).to_a
  end

  def transfer_conflict(source_transactions, destination_transactions, to_account)
    source_transactions.find { |transaction| transaction.transfer? && transaction.destination_account == to_account } ||
      destination_transactions.find { |transaction| transaction.account == to_account }
  end

  def move_source_account(transaction, account)
    delta_cents = source_balance_delta(transaction)
    adjust_balance(transaction.account, -delta_cents)
    transaction.update!(account: account)
    adjust_balance(account, delta_cents)
  end

  def move_destination_account(transaction, account)
    delta_cents = transaction.destination_amount_cents
    adjust_balance(transaction.destination_account, -delta_cents)
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
    attr_reader :errors

    def initialize(moved:, errors: [])
      @moved = moved
      @errors = errors
    end

    def moved? = @moved
  end
end
```

- [ ] **Step 2: Run the service tests and confirm GREEN**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_account_mover_test.rb
```

Expected: 2 runs, 0 failures, 0 errors.

- [ ] **Step 3: Commit the service slice**

Run:

```bash
git add app/services/transaction_account_mover.rb test/services/transaction_account_mover_test.rb
git commit --no-gpg-sign -m "feat: add transaction account mover"
```

---

### Task 3: API RED Tests

**Files:**
- Modify: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Add HTTP contract tests**

Add these tests after the existing batch account tests in `test/integration/api/v1/transactions_test.rb`:

```ruby
  test "moves all transactions between accounts for the token owner" do
    user = create(:user)
    from_account = create_account(user: user, name: "Checking", balance_cents: 4_500)
    to_account = create_account(user: user, name: "Savings", balance_cents: 2_000)
    other_account = create_account(user: user, name: "Brokerage", balance_cents: 20_000)
    expense_category = create_category(user: user, name: "Food", category_type: :expense)
    transfer_category = create_category(user: user, name: "Move", category_type: :transfer)
    expense = create_transaction(
      user: user,
      account: from_account,
      category: expense_category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-04 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    incoming_transfer = create_transaction(
      user: user,
      account: other_account,
      destination_account: from_account,
      category: transfer_category,
      transaction_kind: :transfer,
      transacted_at: Time.zone.parse("2026-05-04 13:00:00"),
      source_amount_cents: 2_000,
      destination_amount_cents: 2_000,
      comment: "Refund"
    )
    raw_token = issue_token(user)

    post move_between_accounts_api_v1_transactions_path,
      params: { from_account_id: from_account.to_param, to_account_id: to_account.to_param },
      headers: json_headers(raw_token),
      as: :json

    assert_response :no_content
    assert_empty response.body
    assert_equal to_account, expense.reload.account
    assert_equal other_account, incoming_transfer.reload.account
    assert_equal to_account, incoming_transfer.destination_account
    assert_equal 3_750, from_account.reload.balance_cents
    assert_equal 2_750, to_account.reload.balance_cents
    assert_equal 20_000, other_account.reload.balance_cents
  end

  test "does not move transactions when the target account is unavailable" do
    user = create(:user)
    other_user = create(:user)
    from_account = create_account(user: user, name: "Checking", balance_cents: 4_500)
    other_account = create_account(user: other_user, name: "Other Savings", balance_cents: 10_000)
    category = create_category(user: user, name: "Food", category_type: :expense)
    transaction = create_transaction(
      user: user,
      account: from_account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-04 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    raw_token = issue_token(user)

    post move_between_accounts_api_v1_transactions_path,
      params: { from_account_id: from_account.to_param, to_account_id: other_account.to_param },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_equal from_account, transaction.reload.account
    assert_equal 4_500, from_account.reload.balance_cents
    assert_equal 10_000, other_account.reload.balance_cents
  end

  test "does not move transactions when source and target accounts match" do
    user = create(:user)
    account = create_account(user: user, name: "Checking", balance_cents: 4_500)
    category = create_category(user: user, name: "Food", category_type: :expense)
    transaction = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-04 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    raw_token = issue_token(user)

    post move_between_accounts_api_v1_transactions_path,
      params: { from_account_id: account.to_param, to_account_id: account.to_param },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_match(/From account must differ from to account/i, response.body)
    assert_equal account, transaction.reload.account
    assert_equal 4_500, account.reload.balance_cents
  end
```

- [ ] **Step 2: Run the API tests and confirm RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb
```

Expected: fails because `move_between_accounts_api_v1_transactions_path` is undefined.

---

### Task 4: API GREEN Implementation

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/policies/transaction_policy.rb`
- Modify: `app/controllers/api/v1/transactions_controller.rb`
- Test: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Add the route**

In `config/routes.rb`, add the collection route inside `resources :transactions`:

```ruby
        post :move_between_accounts, on: :collection
```

- [ ] **Step 2: Add the policy method**

In `app/policies/transaction_policy.rb`, add:

```ruby
  def move_between_accounts? = user.present?
```

- [ ] **Step 3: Add the controller action and helpers**

In `app/controllers/api/v1/transactions_controller.rb`, add the action after `batch_update_account`:

```ruby
  # POST /api/v1/transactions/move_between_accounts
  def move_between_accounts
    authorize Transaction
    result = TransactionAccountMover.new.move_between_accounts(
      user: current_user,
      from_account: move_from_account,
      to_account: move_to_account
    )

    if result.moved?
      head :no_content
    else
      render json: { errors: result.errors }, status: :unprocessable_content
    end
  end
```

Add these private helpers near the batch account helpers:

```ruby
  def move_from_account
    current_user.accounts.kept.find(Account.decode_prefix_id(move_from_account_id) || move_from_account_id)
  end

  def move_from_account_id
    params[:from_account_id].to_s
  end

  def move_to_account
    current_user.accounts.kept.find(Account.decode_prefix_id(move_to_account_id) || move_to_account_id)
  end

  def move_to_account_id
    params[:to_account_id].to_s
  end
```

- [ ] **Step 4: Run the API tests and confirm GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb
```

Expected: 0 failures, 0 errors.

- [ ] **Step 5: Commit the API slice**

Run:

```bash
git add config/routes.rb app/policies/transaction_policy.rb app/controllers/api/v1/transactions_controller.rb test/integration/api/v1/transactions_test.rb
git commit --no-gpg-sign -m "feat: add transaction move between accounts api"
```

---

### Task 5: Focused and Full Verification

**Files:**
- Verify all changed files

- [ ] **Step 1: Run focused tests**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_account_mover_test.rb test/integration/api/v1/transactions_test.rb
```

Expected: 0 failures, 0 errors.

- [ ] **Step 2: Run full Rails tests**

Run:

```bash
mise exec -- bin/rails test
```

Expected: 0 failures, 0 errors.

- [ ] **Step 3: Run targeted RuboCop**

Run:

```bash
mise exec -- bin/rubocop app/services/transaction_account_mover.rb app/controllers/api/v1/transactions_controller.rb app/policies/transaction_policy.rb config/routes.rb test/services/transaction_account_mover_test.rb test/integration/api/v1/transactions_test.rb
```

Expected: no offenses detected.

- [ ] **Step 4: Inspect final diff**

Run:

```bash
git status --short --branch
git diff --stat HEAD~2..HEAD
```

Expected: only this slice's plan, service, controller/policy/route, and tests changed.
