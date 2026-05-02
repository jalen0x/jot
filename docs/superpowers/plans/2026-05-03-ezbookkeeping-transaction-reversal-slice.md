# ezBookkeeping Transaction Reversal Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Rails-native transaction deletion that soft-deletes transactions and reverses account balance effects.

**Architecture:** `TransactionReversal#delete_transaction` owns the ledger reversal in one database transaction. The controller loads the transaction through `policy_scope(Transaction).kept`, authorizes `destroy?`, invokes the service, and redirects; no balance math lives in the controller or model callbacks.

**Tech Stack:** Rails 8.1, PostgreSQL SQL schema, Devise, Pundit, Discard, ViewComponent, Hotwire/Turbo, Flowbite semantic classes, Minitest, FactoryBot.

---

## File Structure

- `app/services/transaction_reversal.rb`: soft-deletes a transaction and reverses balance effects.
- `test/services/transaction_reversal_test.rb`: service coverage for income, expense, transfer, and already-discarded transactions.
- `app/policies/transaction_policy.rb`: add `destroy?`.
- `config/routes.rb`: add `:destroy` to canonical transaction routes.
- `app/controllers/transactions_controller.rb`: add destroy boundary.
- `app/views/transactions/index.html.erb`: add delete button per transaction.
- `test/integration/transactions_test.rb`: HTTP destroy coverage and cross-user protection.

## Task 1: TransactionReversal Service

**Files:**
- Create: `test/services/transaction_reversal_test.rb`
- Create: `app/services/transaction_reversal.rb`

- [ ] **Step 1: Write failing reversal service tests**

Create `test/services/transaction_reversal_test.rb`:

```ruby
require "test_helper"

class TransactionReversalTest < ActiveSupport::TestCase
  test "deletes income and subtracts its amount from the account" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 3_500)
    transaction = create_transaction(user: user, account: account, transaction_kind: :income, source_amount_cents: 2_500)

    result = TransactionReversal.new.delete_transaction(transaction: transaction)

    assert_predicate result, :deleted?
    assert_predicate transaction.reload, :discarded?
    assert_equal 1_000, account.reload.balance_cents
  end

  test "deletes expense and adds its amount back to the account" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 3_800)
    transaction = create_transaction(user: user, account: account, transaction_kind: :expense, source_amount_cents: 1_200)

    result = TransactionReversal.new.delete_transaction(transaction: transaction)

    assert_predicate result, :deleted?
    assert_predicate transaction.reload, :discarded?
    assert_equal 5_000, account.reload.balance_cents
  end

  test "deletes transfer and reverses both account balances" do
    user = create(:user)
    source = create_account(user: user, name: "Checking", balance_cents: 3_000)
    destination = create_account(user: user, name: "Savings", balance_cents: 3_000)
    transaction = create_transaction(
      user: user,
      account: source,
      destination_account: destination,
      transaction_kind: :transfer,
      source_amount_cents: 2_000,
      destination_amount_cents: 2_000,
      category_type: :transfer
    )

    result = TransactionReversal.new.delete_transaction(transaction: transaction)

    assert_predicate result, :deleted?
    assert_predicate transaction.reload, :discarded?
    assert_equal 5_000, source.reload.balance_cents
    assert_equal 1_000, destination.reload.balance_cents
  end

  test "does not reverse an already discarded transaction twice" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 3_500)
    transaction = create_transaction(user: user, account: account, transaction_kind: :income, source_amount_cents: 2_500)
    transaction.discard!

    result = TransactionReversal.new.delete_transaction(transaction: transaction)

    refute_predicate result, :deleted?
    assert_includes result.transaction.errors[:base], "Transaction is already deleted"
    assert_equal 3_500, account.reload.balance_cents
  end

  private

  def create_transaction(user:, account:, transaction_kind:, source_amount_cents:, destination_account: nil, destination_amount_cents: 0, category_type: transaction_kind)
    Transaction.create!(
      user: user,
      account: account,
      destination_account: destination_account,
      transaction_category: create_category(user: user, category_type: category_type),
      transaction_kind: transaction_kind,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: source_amount_cents,
      destination_amount_cents: destination_amount_cents,
      comment: "Original"
    )
  end

  def create_account(user:, name: "Cash", balance_cents:)
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
end
```

- [ ] **Step 2: Run reversal tests to verify RED**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_reversal_test.rb
```

Expected: FAIL with `uninitialized constant TransactionReversal`.

- [ ] **Step 3: Implement TransactionReversal**

Create `app/services/transaction_reversal.rb`:

```ruby
class TransactionReversal
  def delete_transaction(transaction:)
    if transaction.discarded?
      transaction.errors.add(:base, "Transaction is already deleted")
      return Result.new(deleted: false, transaction: transaction)
    end

    ActiveRecord::Base.transaction do
      reverse_balances(transaction)
      transaction.discard!
    end

    Result.new(deleted: true, transaction: transaction)
  end

  private

  def reverse_balances(transaction)
    case transaction.transaction_kind
    when "balance_adjustment"
      transaction.account.update!(balance_cents: transaction.account.balance_cents - transaction.source_amount_cents)
    when "income"
      transaction.account.update!(balance_cents: transaction.account.balance_cents - transaction.source_amount_cents)
    when "expense"
      transaction.account.update!(balance_cents: transaction.account.balance_cents + transaction.source_amount_cents)
    when "transfer"
      transaction.account.update!(balance_cents: transaction.account.balance_cents + transaction.source_amount_cents)
      transaction.destination_account.update!(balance_cents: transaction.destination_account.balance_cents - transaction.destination_amount_cents)
    end
  end

  class Result
    attr_reader :transaction

    def initialize(deleted:, transaction:)
      @deleted = deleted
      @transaction = transaction
    end

    def deleted? = @deleted
  end
end
```

- [ ] **Step 4: Run reversal tests to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_reversal_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit TransactionReversal**

Run:

```bash
git add app/services/transaction_reversal.rb test/services/transaction_reversal_test.rb
git commit -m "feat: reverse deleted transactions"
```

## Task 2: Destroy Route And UI

**Files:**
- Modify: `test/integration/transactions_test.rb`
- Modify: `app/policies/transaction_policy.rb`
- Modify: `config/routes.rb`
- Modify: `app/controllers/transactions_controller.rb`
- Modify: `app/views/transactions/index.html.erb`

- [ ] **Step 1: Write failing destroy integration tests**

Append these tests to `test/integration/transactions_test.rb` before `private`:

```ruby
  test "deletes a transaction for current user" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 3_800)
    transaction = create_transaction(user: user, comment: "Lunch")
    transaction.update!(account: account, source_amount_cents: 1_200)
    sign_in user

    delete transaction_path(transaction)

    assert_redirected_to transactions_path
    assert_predicate transaction.reload, :discarded?
    assert_equal 5_000, account.reload.balance_cents
  end

  test "does not delete another user's transaction" do
    user = create(:user)
    other_user = create(:user)
    transaction = create_transaction(user: other_user, comment: "Other Lunch")
    sign_in user

    delete transaction_path(transaction)

    assert_response :not_found
    refute_predicate transaction.reload, :discarded?
  end
```

- [ ] **Step 2: Run destroy integration tests to verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/transactions_test.rb
```

Expected: FAIL with route missing `DELETE /transactions/:id` or `No route matches`.

- [ ] **Step 3: Add route, policy, and controller action**

Modify `config/routes.rb` transaction route to:

```ruby
  resources :transactions, only: [ :index, :new, :create, :destroy ]
```

Modify `app/policies/transaction_policy.rb` to add:

```ruby
  def destroy? = user.present? && record.user_id == user.id
```

Modify `app/controllers/transactions_controller.rb` after `create`:

```ruby
  # DELETE /transactions/:id
  def destroy
    transaction = policy_scope(Transaction).kept.find(params[:id])
    authorize transaction
    result = TransactionReversal.new.delete_transaction(transaction: transaction)

    if result.deleted?
      redirect_to transactions_path, notice: "Transaction deleted."
    else
      redirect_to transactions_path, alert: result.transaction.errors.full_messages.to_sentence
    end
  end
```

- [ ] **Step 4: Add delete button to the transaction list**

In `app/views/transactions/index.html.erb`, add this button inside each transaction `<li>` after the amount/type block:

```erb
            <div class="flex justify-end sm:justify-start">
              <%= button_to "Delete", transaction_path(transaction), method: :delete, class: "text-danger bg-neutral-primary border border-danger hover:bg-danger hover:text-white focus:ring-4 focus:ring-neutral-tertiary font-medium leading-5 rounded-base text-sm px-4 py-2.5 focus:outline-none" %>
            </div>
```

- [ ] **Step 5: Run integration tests to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/transactions_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit destroy UI**

Run:

```bash
git add app/policies/transaction_policy.rb config/routes.rb app/controllers/transactions_controller.rb app/views/transactions/index.html.erb test/integration/transactions_test.rb
git commit -m "feat: delete ledger transactions"
```

## Task 3: Slice Verification

**Files:**
- Verify: all files changed in Tasks 1-2

- [ ] **Step 1: Run targeted tests**

Run:

```bash
mise exec -- bin/rails test test/services/transaction_reversal_test.rb test/integration/transactions_test.rb test/services/ledger_query_test.rb
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
git add app test config
git commit -m "style: clean transaction reversal slice"
```

Expected: commit is created only if lint produced edits.

## Self-Review Checklist

- Spec coverage: Implements the Phase 1 `TransactionReversal#delete_transaction` seam for soft deletion and balance reversal. Editing, batch deletion, transaction pictures, reconciliation, reports, imports, settings, schedules, API, AI, and MCP remain outside this slice.
- Placeholder scan: every step has concrete files, code, commands, and expected outcomes.
- Type consistency: uses existing `discard` soft-delete semantics and existing single-row transfer fields `destination_account_id` / `destination_amount_cents`.
- Source alignment: mirrors ezBookkeeping balance reversal rules for income, expense, and transfer; Rails does not need to delete a paired transfer-in row because transfers are represented as one row in the Rails rewrite.
