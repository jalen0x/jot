# ezBookkeeping Ledger Trends Service Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `LedgerTrends#build_transaction_trends(user:, range:, aggregation:, filters:)` for chart-ready daily/monthly income, expense, and net buckets.

**Architecture:** Keep trend aggregation in a service object. Reuse `LedgerQuery` for user scoping and existing account/category/tag/type filters, then apply the requested date range and aggregate kept income/expense transactions into complete day or month buckets. This slice adds no UI or API route so the aggregation contract is tested narrowly first.

**Tech Stack:** Rails 8.1, Active Record, existing `LedgerQuery`, Minitest service tests.

---

## File Structure

- Create `app/services/ledger_trends.rb`: service, result object, and bucket value object.
- Create `test/services/ledger_trends_test.rb`: service tests for daily buckets, monthly buckets, filters, empty buckets, and current-user scoping.

---

### Task 1: Add `LedgerTrends` service

**Files:**
- Create: `test/services/ledger_trends_test.rb`
- Create: `app/services/ledger_trends.rb`

- [ ] **Step 1: Write failing service tests**

Create `test/services/ledger_trends_test.rb` with tests for:

1. Daily aggregation returns one bucket per day in the requested range, including empty days.
2. Income adds to `income_cents`, expense adds to `expense_cents`, and `net_cents` is income minus expense.
3. Transfers and balance adjustments are ignored for income/expense trend totals.
4. Other users' transactions are ignored.
5. Monthly aggregation returns one bucket per month and respects existing prefixed ID filters through `LedgerQuery`.

Use explicit dates and cents so wrong bucketing, ordering, sign handling, or scoping fails loudly.

- [ ] **Step 2: Run trend tests RED**

Run: `mise exec -- bin/rails test test/services/ledger_trends_test.rb`

Expected: FAIL because `LedgerTrends` is not defined.

- [ ] **Step 3: Implement the service**

Create `app/services/ledger_trends.rb`:

```ruby
class LedgerTrends
  Bucket = Struct.new(:starts_on, :income_cents, :expense_cents, :net_cents, keyword_init: true)

  def build_transaction_trends(user:, range:, aggregation:, filters: {})
    transactions = LedgerQuery.new.list_transactions(user: user, filters: filters).where(transacted_at: range)
    totals = totals_by_bucket(transactions, aggregation)
    buckets = bucket_starts(range, aggregation).map do |starts_on|
      income_cents = totals.dig(starts_on, :income_cents).to_i
      expense_cents = totals.dig(starts_on, :expense_cents).to_i

      Bucket.new(
        starts_on: starts_on,
        income_cents: income_cents,
        expense_cents: expense_cents,
        net_cents: income_cents - expense_cents
      )
    end

    Result.new(range: range, aggregation: aggregation.to_s, buckets: buckets)
  end

  private

  def totals_by_bucket(transactions, aggregation)
    totals = Hash.new { |hash, key| hash[key] = { income_cents: 0, expense_cents: 0 } }

    transactions.find_each do |transaction|
      next unless transaction.income? || transaction.expense?

      starts_on = bucket_start(transaction.transacted_at.to_date, aggregation)
      if transaction.income?
        totals[starts_on][:income_cents] += transaction.source_amount_cents
      else
        totals[starts_on][:expense_cents] += transaction.source_amount_cents
      end
    end

    totals
  end

  def bucket_starts(range, aggregation)
    case aggregation.to_s
    when "day"
      (range.begin.to_date..range.end.to_date).to_a
    when "month"
      month_starts(range.begin.to_date.beginning_of_month, range.end.to_date.beginning_of_month)
    else
      raise ArgumentError, "Unsupported trend aggregation"
    end
  end

  def bucket_start(date, aggregation)
    aggregation.to_s == "month" ? date.beginning_of_month : date
  end

  def month_starts(first_month, last_month)
    months = []
    current_month = first_month
    while current_month <= last_month
      months << current_month
      current_month = current_month.next_month
    end
    months
  end

  class Result
    attr_reader :range, :aggregation, :buckets

    def initialize(range:, aggregation:, buckets:)
      @range = range
      @aggregation = aggregation
      @buckets = buckets
    end
  end
end
```

- [ ] **Step 4: Run trend tests GREEN**

Run: `mise exec -- bin/rails test test/services/ledger_trends_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit trends service**

```bash
git add app/services/ledger_trends.rb test/services/ledger_trends_test.rb
git commit --no-gpg-sign -m "feat: add ledger trends service"
```

---

### Task 2: Verify ledger trends service slice

- [ ] **Step 1: Run focused service tests**

Run: `mise exec -- bin/rails test test/services/ledger_trends_test.rb test/services/ledger_query_test.rb test/services/ledger_statistics_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run lint for touched files**

Run: `mise exec -- bin/rubocop app/services/ledger_trends.rb test/services/ledger_trends_test.rb`

Expected: PASS.

- [ ] **Step 4: Check git status**

Run: `git status --short`

Expected: clean working tree.

---

## Self-Review

- Spec coverage: implements the Phase 2 `LedgerTrends#build_transaction_trends(user:, range:, aggregation:, filters:)` seam from the rewrite design with chart-ready buckets.
- Scope control: does not add report-page charts, chart libraries, API routes, asset trends, saved explorers, or cached snapshots.
- Placeholder scan: no TODO/TBD placeholders remain.
- Type consistency: buckets expose dates and integer cents; aggregation is stored as a string for predictable rendering later.
