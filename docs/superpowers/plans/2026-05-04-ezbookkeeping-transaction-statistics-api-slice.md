# Transaction Statistics API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modern Rails API endpoint for transaction income/expense/net statistics.

**Architecture:** Add `GET /api/v1/transactions/statistics` as a collection action under the existing Rails-native transactions resource. The controller authorizes the transaction collection, parses optional ISO `start_date`/`end_date` params at the API boundary, reuses `LedgerStatistics`, and returns a simple `{ statistics: ... }` JSON object. Do not add ezBookkeeping legacy `.json` routes, `success/result` envelopes, camelCase params, or old frontend compatibility.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit, existing `LedgerStatistics` and `LedgerQuery` filters.

---

## File Structure

- Modify `config/routes.rb`: add collection route `get :statistics` under `api/v1/transactions`.
- Modify `app/policies/transaction_policy.rb`: allow authenticated API users to call statistics.
- Modify `app/controllers/api/v1/transactions_controller.rb`: add `statistics` action, date parsing helpers, and JSON presenter.
- Modify `test/integration/api/v1/transactions_test.rb`: add HTTP contract tests for scoped date-range statistics and invalid date handling.

---

### Task 1: API RED Tests

**Files:**
- Modify: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Add statistics endpoint tests**

Add these tests after `test "counts transactions with existing filters"` in `test/integration/api/v1/transactions_test.rb`:

```ruby
  test "summarizes transaction statistics for the token owner" do
    user = create(:user)
    other_user = create(:user)
    matching_account = create_account(user: user, name: "Checking")
    other_account = create_account(user: user, name: "Savings")
    salary = create_category(user: user, name: "Salary", category_type: :income)
    food = create_category(user: user, name: "Food", category_type: :expense)
    create_transaction(
      user: user,
      account: matching_account,
      category: salary,
      transaction_kind: :income,
      transacted_at: Time.zone.parse("2026-05-04 09:00:00"),
      source_amount_cents: 5_000,
      comment: "Paycheck"
    )
    create_transaction(
      user: user,
      account: matching_account,
      category: food,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-04 10:00:00"),
      source_amount_cents: 1_200,
      comment: "Lunch"
    )
    create_transaction(
      user: user,
      account: other_account,
      category: food,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-04 11:00:00"),
      source_amount_cents: 300,
      comment: "Coffee"
    )
    create_transaction(
      user: user,
      account: matching_account,
      category: salary,
      transaction_kind: :income,
      transacted_at: Time.zone.parse("2026-06-01 09:00:00"),
      source_amount_cents: 9_999,
      comment: "June Paycheck"
    )
    create_transaction(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Salary", category_type: :income),
      transaction_kind: :income,
      transacted_at: Time.zone.parse("2026-05-04 09:00:00"),
      source_amount_cents: 7_777,
      comment: "Other Paycheck"
    )
    raw_token = issue_token(user)

    get statistics_api_v1_transactions_path,
      params: { start_date: "2026-05-01", end_date: "2026-05-31", account_id: matching_account.to_param },
      headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "statistics" ], body.keys
    statistics = body.fetch("statistics")
    assert_equal 5_000, statistics.fetch("income_cents")
    assert_equal 1_200, statistics.fetch("expense_cents")
    assert_equal 3_800, statistics.fetch("net_cents")
    assert_equal({ "Salary" => 5_000, "Food" => -1_200 }, statistics.fetch("category_totals"))
    assert_equal({ "Checking" => 3_800 }, statistics.fetch("account_totals"))
  end

  test "rejects invalid transaction statistics dates" do
    user = create(:user)
    raw_token = issue_token(user)

    get statistics_api_v1_transactions_path,
      params: { start_date: "not-a-date", end_date: "2026-05-31" },
      headers: json_headers(raw_token)

    assert_response :unprocessable_content
    assert_match(/valid ISO 8601 dates/i, response.body)
  end
```

- [ ] **Step 2: Run the integration tests and confirm RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb
```

Expected: fails because `statistics_api_v1_transactions_path` is undefined.

---

### Task 2: API GREEN Implementation

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/policies/transaction_policy.rb`
- Modify: `app/controllers/api/v1/transactions_controller.rb`
- Test: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Add route**

In `config/routes.rb`, add this collection route under `resources :transactions`:

```ruby
        get :statistics, on: :collection
```

- [ ] **Step 2: Add policy method**

In `app/policies/transaction_policy.rb`, add:

```ruby
  def statistics? = user.present?
```

- [ ] **Step 3: Add controller action and helpers**

Add this action after `count` in `app/controllers/api/v1/transactions_controller.rb`:

```ruby
  # GET /api/v1/transactions/statistics
  def statistics
    authorize Transaction
    summary = LedgerStatistics.new.summarize_transactions(user: current_user, range: statistics_range, filters: filter_params)

    render json: { statistics: statistics_json(summary) }
  rescue Date::Error
    render json: { errors: [ "Start date and end date must be valid ISO 8601 dates" ] }, status: :unprocessable_content
  end
```

Add these private helpers:

```ruby
  def statistics_range
    start_date = parsed_date(params[:start_date]) || Time.zone.today.beginning_of_month
    end_date = parsed_date(params[:end_date]) || Time.zone.today.end_of_month

    start_date.beginning_of_day..end_date.end_of_day
  end

  def parsed_date(value)
    return if value.blank?

    Date.iso8601(value)
  end

  def statistics_json(summary)
    {
      income_cents: summary.income_cents,
      expense_cents: summary.expense_cents,
      net_cents: summary.net_cents,
      category_totals: summary.category_totals,
      account_totals: summary.account_totals
    }
  end
```

- [ ] **Step 4: Run the integration tests and confirm GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb
```

Expected: 0 failures, 0 errors.

- [ ] **Step 5: Commit the API slice**

Run:

```bash
git add config/routes.rb app/controllers/api/v1/transactions_controller.rb app/policies/transaction_policy.rb test/integration/api/v1/transactions_test.rb
git commit --no-gpg-sign -m "feat: add transaction statistics api"
```

---

### Task 3: Verification

**Files:**
- Verify all changed files

- [ ] **Step 1: Run focused tests**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb
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
mise exec -- bin/rubocop app/controllers/api/v1/transactions_controller.rb app/policies/transaction_policy.rb config/routes.rb test/integration/api/v1/transactions_test.rb
```

Expected: no offenses detected.

- [ ] **Step 4: Inspect final diff**

Run:

```bash
git status --short --branch
git diff --stat HEAD~1..HEAD
```

Expected: only this slice's route, controller, policy, integration test, and plan changed.
