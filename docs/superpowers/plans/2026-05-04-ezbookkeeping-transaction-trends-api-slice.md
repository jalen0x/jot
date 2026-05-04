# Transaction Trends API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modern Rails API endpoint for daily/monthly transaction income and expense trends.

**Architecture:** Add `GET /api/v1/transactions/trends` as a collection action under the existing Rails-native transactions resource. The controller authorizes the transaction collection, parses optional ISO `start_date`/`end_date`, accepts `aggregation=day|month`, reuses `LedgerTrends`, and returns `{ trends: ... }`. Do not add ezBookkeeping legacy `.json` routes, `success/result` envelopes, camelCase params, or old frontend compatibility.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit, existing `LedgerTrends` and `LedgerQuery` filters.

---

## File Structure

- Modify `config/routes.rb`: add collection route `get :trends` under `api/v1/transactions`.
- Modify `app/policies/transaction_policy.rb`: allow authenticated API users to call trends.
- Modify `app/controllers/api/v1/transactions_controller.rb`: add `trends` action and JSON presenter.
- Modify `test/integration/api/v1/transactions_test.rb`: add HTTP contract tests for scoped trends and invalid aggregation handling.

---

### Task 1: API RED Tests

**Files:**
- Modify: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Add trends endpoint tests**

Add these tests after `test "rejects invalid transaction statistics dates"` in `test/integration/api/v1/transactions_test.rb`:

```ruby
  test "returns transaction trends for the token owner" do
    user = create(:user)
    other_user = create(:user)
    matching_account = create_account(user: user, name: "Checking")
    other_account = create_account(user: user, name: "Savings")
    income_category = create_category(user: user, name: "Salary", category_type: :income)
    expense_category = create_category(user: user, name: "Food", category_type: :expense)
    create_transaction(
      user: user,
      account: matching_account,
      category: income_category,
      transaction_kind: :income,
      transacted_at: Time.zone.parse("2026-05-01 09:00:00"),
      source_amount_cents: 5_000,
      comment: "Paycheck"
    )
    create_transaction(
      user: user,
      account: matching_account,
      category: expense_category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      source_amount_cents: 1_200,
      comment: "Lunch"
    )
    create_transaction(
      user: user,
      account: other_account,
      category: income_category,
      transaction_kind: :income,
      transacted_at: Time.zone.parse("2026-05-01 11:00:00"),
      source_amount_cents: 9_999,
      comment: "Other Account Paycheck"
    )
    create_transaction(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Salary", category_type: :income),
      transaction_kind: :income,
      transacted_at: Time.zone.parse("2026-05-01 09:00:00"),
      source_amount_cents: 7_777,
      comment: "Other Paycheck"
    )
    raw_token = issue_token(user)

    get trends_api_v1_transactions_path,
      params: { start_date: "2026-05-01", end_date: "2026-05-03", aggregation: "day", account_id: matching_account.to_param },
      headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "trends" ], body.keys
    trends = body.fetch("trends")
    assert_equal "day", trends.fetch("aggregation")
    assert_equal [
      { "starts_on" => "2026-05-01", "income_cents" => 5_000, "expense_cents" => 0, "net_cents" => 5_000 },
      { "starts_on" => "2026-05-02", "income_cents" => 0, "expense_cents" => 0, "net_cents" => 0 },
      { "starts_on" => "2026-05-03", "income_cents" => 0, "expense_cents" => 1_200, "net_cents" => -1_200 }
    ], trends.fetch("buckets")
  end

  test "rejects invalid transaction trend aggregation" do
    user = create(:user)
    raw_token = issue_token(user)

    get trends_api_v1_transactions_path,
      params: { start_date: "2026-05-01", end_date: "2026-05-03", aggregation: "week" },
      headers: json_headers(raw_token)

    assert_response :unprocessable_content
    assert_match(/Aggregation must be day or month/i, response.body)
  end
```

- [ ] **Step 2: Run the integration tests and confirm RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb
```

Expected: fails because `trends_api_v1_transactions_path` is undefined.

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
        get :trends, on: :collection
```

- [ ] **Step 2: Add policy method**

In `app/policies/transaction_policy.rb`, add:

```ruby
  def trends? = user.present?
```

- [ ] **Step 3: Add controller action and helper**

Add this action after `statistics` in `app/controllers/api/v1/transactions_controller.rb`:

```ruby
  # GET /api/v1/transactions/trends
  def trends
    authorize Transaction
    trends = LedgerTrends.new.build_transaction_trends(user: current_user, range: statistics_range, aggregation: trends_aggregation, filters: filter_params)

    render json: { trends: trends_json(trends) }
  rescue Date::Error
    render json: { errors: [ "Start date and end date must be valid ISO 8601 dates" ] }, status: :unprocessable_content
  rescue ArgumentError
    render json: { errors: [ "Aggregation must be day or month" ] }, status: :unprocessable_content
  end
```

Add these private helpers near `statistics_json`:

```ruby
  def trends_aggregation
    params[:aggregation].presence || "day"
  end

  def trends_json(trends)
    {
      aggregation: trends.aggregation,
      buckets: trends.buckets.map do |bucket|
        {
          starts_on: bucket.starts_on.iso8601,
          income_cents: bucket.income_cents,
          expense_cents: bucket.expense_cents,
          net_cents: bucket.net_cents
        }
      end
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
git commit --no-gpg-sign -m "feat: add transaction trends api"
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
