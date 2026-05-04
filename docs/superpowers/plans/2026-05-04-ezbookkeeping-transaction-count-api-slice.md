# Transaction Count API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modern Rails API endpoint for counting the current user's kept transactions with the same filters used by transaction index.

**Architecture:** Add a Rails-native collection route, `GET /api/v1/transactions/count`, that authorizes the transaction collection and reuses `LedgerQuery#list_transactions` with existing `filter_params`. The response is a simple modern JSON object, `{ count: n }`. Do not add ezBookkeeping legacy `.json` routes, `success/result` envelopes, camelCase params, or old frontend compatibility.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit, existing `LedgerQuery` filter behavior.

---

## File Structure

- Modify `config/routes.rb`: add a collection `get :count` route under `api/v1/transactions`.
- Modify `app/controllers/api/v1/transactions_controller.rb`: add `count` action using `LedgerQuery` and `filter_params`.
- Modify `app/policies/transaction_policy.rb`: allow authenticated API users to count transactions.
- Modify `test/integration/api/v1/transactions_test.rb`: add HTTP contract tests for owner scoping, kept scoping, and filters.

---

### Task 1: API RED Tests

**Files:**
- Modify: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Add count endpoint tests**

Add these tests after `test "does not show another user's transaction"` in `test/integration/api/v1/transactions_test.rb`:

```ruby
  test "counts only the token owner's kept transactions" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Food", category_type: :expense)
    create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-04 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    discarded = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-04 13:00:00"),
      source_amount_cents: 500,
      comment: "Archived"
    )
    discarded.discard!
    create_transaction(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Food", category_type: :expense),
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-04 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Other Lunch"
    )
    raw_token = issue_token(user)

    get count_api_v1_transactions_path, headers: json_headers(raw_token)

    assert_response :success
    assert_equal({ "count" => 1 }, JSON.parse(response.body))
  end

  test "counts transactions with existing filters" do
    user = create(:user)
    matching_account = create_account(user: user, name: "Checking")
    other_account = create_account(user: user, name: "Savings")
    category = create_category(user: user, name: "Food", category_type: :expense)
    create_transaction(
      user: user,
      account: matching_account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-04 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch"
    )
    create_transaction(
      user: user,
      account: other_account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-04 13:00:00"),
      source_amount_cents: 500,
      comment: "Coffee"
    )
    raw_token = issue_token(user)

    get count_api_v1_transactions_path, params: { account_id: matching_account.to_param }, headers: json_headers(raw_token)

    assert_response :success
    assert_equal({ "count" => 1 }, JSON.parse(response.body))
  end
```

- [ ] **Step 2: Run the integration tests and confirm RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb
```

Expected: fails because `count_api_v1_transactions_path` is undefined.

---

### Task 2: API GREEN Implementation

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/api/v1/transactions_controller.rb`
- Modify: `app/policies/transaction_policy.rb`
- Test: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Add the route**

In `config/routes.rb`, add this collection route inside `resources :transactions`:

```ruby
        get :count, on: :collection
```

- [ ] **Step 2: Add the policy method**

In `app/policies/transaction_policy.rb`, add:

```ruby
  def count? = user.present?
```

- [ ] **Step 3: Add the controller action**

Add this action after `index` in `app/controllers/api/v1/transactions_controller.rb`:

```ruby
  # GET /api/v1/transactions/count
  def count
    authorize Transaction
    count = LedgerQuery.new.list_transactions(user: current_user, filters: filter_params).count

    render json: { count: count }
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
git commit --no-gpg-sign -m "feat: add transaction count api"
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

Expected: only this slice's route, controller, policy, integration tests, and plan changed.
