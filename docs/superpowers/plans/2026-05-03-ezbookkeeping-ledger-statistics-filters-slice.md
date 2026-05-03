# ezBookkeeping Ledger Statistics Filters Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `LedgerStatistics#summarize_transactions(user:, range:, filters:)` with existing ledger filters and account totals.

**Architecture:** Keep summary aggregation inside `LedgerStatistics`. Reuse `LedgerQuery` for current-user scoping and account/category/tag/type filters, then apply the date range and aggregate kept income/expense transactions. Preserve the existing controller call by making `filters:` optional.

**Tech Stack:** Rails 8.1, Active Record, existing `LedgerQuery`, Minitest service tests.

---

## File Structure

- Modify `app/services/ledger_statistics.rb`: optional filters arg, `LedgerQuery` source relation, and `account_totals` result.
- Modify `test/services/ledger_statistics_test.rb`: account totals, filters, and existing behavior coverage.

---

### Task 1: Extend `LedgerStatistics`

**Files:**
- Modify: `test/services/ledger_statistics_test.rb`
- Modify: `app/services/ledger_statistics.rb`

- [ ] **Step 1: Write failing service tests**

Add tests proving:

1. `summary.account_totals` returns signed totals by account name for income and expense transactions.
2. `summarize_transactions` accepts `filters:` and respects existing prefixed account/category/tag filters through `LedgerQuery`.
3. Existing no-filter calls still work for `ReportsController`.

Use decoy transactions so missing filters or wrong account aggregation fails loudly.

- [ ] **Step 2: Run statistics tests RED**

Run: `mise exec -- bin/rails test test/services/ledger_statistics_test.rb`

Expected: FAIL because `filters:` and `account_totals` are missing.

- [ ] **Step 3: Implement filters and account totals**

Update `app/services/ledger_statistics.rb`:

```ruby
def summarize_transactions(user:, range:, filters: {})
  transactions = LedgerQuery.new.list_transactions(user: user, filters: filters).where(transacted_at: range)
  income_cents = transactions.income.sum(:source_amount_cents)
  expense_cents = transactions.expense.sum(:source_amount_cents)

  Result.new(
    income_cents: income_cents,
    expense_cents: expense_cents,
    net_cents: income_cents - expense_cents,
    category_totals: category_totals(transactions),
    account_totals: account_totals(transactions)
  )
end
```

Add `account_totals(transactions)` mirroring `category_totals`, using `transaction.account.name` and signed income/expense amounts. Update `Result` to expose `account_totals`.

- [ ] **Step 4: Run statistics tests GREEN**

Run: `mise exec -- bin/rails test test/services/ledger_statistics_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit statistics extension**

```bash
git add app/services/ledger_statistics.rb test/services/ledger_statistics_test.rb
git commit --no-gpg-sign -m "feat: add filtered ledger statistics"
```

---

### Task 2: Verify ledger statistics slice

- [ ] **Step 1: Run focused service and report tests**

Run: `mise exec -- bin/rails test test/services/ledger_statistics_test.rb test/services/ledger_query_test.rb test/integration/reports_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run lint for touched files**

Run: `mise exec -- bin/rubocop app/services/ledger_statistics.rb test/services/ledger_statistics_test.rb`

Expected: PASS.

- [ ] **Step 4: Check git status**

Run: `git status --short`

Expected: clean working tree.

---

## Self-Review

- Spec coverage: implements the `filters:` and `account_totals` portions of the Phase 2 `LedgerStatistics` design while preserving existing reports behavior.
- Scope control: does not add chart rendering, report-page filter controls, account reconciliation UI, saved explorers, or new API routes.
- Placeholder scan: no TODO/TBD placeholders remain.
- Type consistency: income/expense/net/account/category totals all remain integer cents.
