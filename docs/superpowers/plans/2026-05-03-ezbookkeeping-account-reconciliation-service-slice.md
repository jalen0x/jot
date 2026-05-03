# ezBookkeeping Account Reconciliation Service Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Phase 2 `AccountReconciliation#build_statement(account:, range:)` service for opening/closing balances, period inflows/outflows, and ordered account transactions.

**Architecture:** Keep reconciliation logic in a service object, not controllers or models. The caller passes an already scoped `Account`; the service reads that account owner's kept transactions where the account is source or destination and computes account-local effects from existing Rails transaction semantics. This slice intentionally adds no UI or API route so the financial algorithm can be tested narrowly first.

**Tech Stack:** Rails 8.1, Active Record, Minitest service tests, existing `Account` and `Transaction` models.

---

## File Structure

- Create `app/services/account_reconciliation.rb`: service and result object.
- Create `test/services/account_reconciliation_test.rb`: service tests for balances, ordering, transfers, discarded records, and user scoping by account owner.

---

### Task 1: Add `AccountReconciliation` service

**Files:**
- Create: `test/services/account_reconciliation_test.rb`
- Create: `app/services/account_reconciliation.rb`

- [ ] **Step 1: Write failing service tests**

Create `test/services/account_reconciliation_test.rb` with tests for these behaviors:

1. Opening balance is the sum of kept transaction effects before `range.begin`; closing balance is opening plus in-range effects.
2. In-range transactions are ordered by `transacted_at ASC, id ASC` and exclude transactions after the range.
3. Expenses count as outflows, income and positive balance adjustments count as inflows.
4. Transfers count as an outflow for the source account and an inflow for the destination account.
5. Discarded transactions and other users' transactions do not affect the statement.

Use explicit cents values and decoy transactions so wrong scoping, ordering, or sign handling fails loudly.

- [ ] **Step 2: Run reconciliation tests RED**

Run: `mise exec -- bin/rails test test/services/account_reconciliation_test.rb`

Expected: FAIL because `AccountReconciliation` is not defined.

- [ ] **Step 3: Implement the service**

Create `app/services/account_reconciliation.rb`:

```ruby
class AccountReconciliation
  def build_statement(account:, range:)
    transactions = account_transactions(account)
    period_transactions = transactions.where(transacted_at: range).order(:transacted_at, :id).to_a
    opening_balance_cents = transactions.where("transacted_at < ?", range.begin).sum { |transaction| account_effect(transaction, account) }
    period_effects = period_transactions.map { |transaction| account_effect(transaction, account) }
    inflow_cents = period_effects.select(&:positive?).sum
    outflow_cents = period_effects.select(&:negative?).sum.abs

    Result.new(
      account: account,
      range: range,
      opening_balance_cents: opening_balance_cents,
      closing_balance_cents: opening_balance_cents + inflow_cents - outflow_cents,
      inflow_cents: inflow_cents,
      outflow_cents: outflow_cents,
      transactions: period_transactions
    )
  end

  private

  def account_transactions(account)
    account.user.transactions.kept
      .includes(:account, :destination_account, :transaction_category)
      .where("account_id = :account_id OR destination_account_id = :account_id", account_id: account.id)
  end

  def account_effect(transaction, account)
    case transaction.transaction_kind
    when "balance_adjustment", "income"
      transaction.account_id == account.id ? transaction.source_amount_cents : 0
    when "expense"
      transaction.account_id == account.id ? -transaction.source_amount_cents : 0
    when "transfer"
      transfer_effect(transaction, account)
    else
      0
    end
  end

  def transfer_effect(transaction, account)
    effect = 0
    effect -= transaction.source_amount_cents if transaction.account_id == account.id
    effect += transaction.destination_amount_cents if transaction.destination_account_id == account.id
    effect
  end

  class Result
    attr_reader :account, :range, :opening_balance_cents, :closing_balance_cents, :inflow_cents, :outflow_cents, :transactions

    def initialize(account:, range:, opening_balance_cents:, closing_balance_cents:, inflow_cents:, outflow_cents:, transactions:)
      @account = account
      @range = range
      @opening_balance_cents = opening_balance_cents
      @closing_balance_cents = closing_balance_cents
      @inflow_cents = inflow_cents
      @outflow_cents = outflow_cents
      @transactions = transactions
    end
  end
end
```

- [ ] **Step 4: Run reconciliation tests GREEN**

Run: `mise exec -- bin/rails test test/services/account_reconciliation_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit reconciliation service**

```bash
git add app/services/account_reconciliation.rb test/services/account_reconciliation_test.rb
git commit --no-gpg-sign -m "feat: add account reconciliation service"
```

---

### Task 2: Verify account reconciliation service slice

- [ ] **Step 1: Run focused service tests**

Run: `mise exec -- bin/rails test test/services/account_reconciliation_test.rb test/services/transaction_recorder_test.rb test/services/transaction_reversal_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run lint for touched files**

Run: `mise exec -- bin/rubocop app/services/account_reconciliation.rb test/services/account_reconciliation_test.rb`

Expected: PASS.

- [ ] **Step 4: Check git status**

Run: `git status --short`

Expected: clean working tree.

---

## Self-Review

- Spec coverage: implements the Phase 2 `AccountReconciliation#build_statement(account:, range:)` seam from the rewrite design. It prepares the account statement algorithm without adding UI, API, saved explorers, or trend charts.
- Scope control: does not add report-page rendering, account selector UI, export formats, reconciliation persistence, generated balances, or cached snapshots.
- Placeholder scan: no TODO/TBD placeholders remain.
- Type consistency: all money values are integer cents; transactions are existing `Transaction` records ordered by time and id.
