# Transaction Show API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modern Rails API endpoint for fetching one current-user transaction by ID.

**Architecture:** Extend the existing Rails-native `api/v1/transactions` resource with the standard `show` action. Reuse the existing `scoped_transaction` helper and `Transaction#as_json` response shape so ownership scoping, discarded filtering, and JSON fields stay consistent with index/update/delete. Do not add ezBookkeeping legacy `.json` routes, `success/result` envelopes, camelCase params, or old frontend compatibility.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit, existing `Transaction#as_json`.

---

## File Structure

- Modify `config/routes.rb`: include `:show` in `api/v1` transaction routes.
- Modify `app/controllers/api/v1/transactions_controller.rb`: add `show` action that renders `{ transaction: scoped_transaction }`.
- Modify `test/integration/api/v1/transactions_test.rb`: add HTTP contract tests for success and current-user scoping.

---

### Task 1: API RED Tests

**Files:**
- Modify: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Add show endpoint tests**

Add these tests after `test "lists only the token owner's kept transactions"` in `test/integration/api/v1/transactions_test.rb`:

```ruby
  test "shows one transaction for the token owner" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Food", category_type: :expense)
    tag = create_tag(user: user, name: "Meals")
    transaction = create_transaction(
      user: user,
      account: account,
      category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-04 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Lunch",
      tags: [ tag ],
      geo_latitude: 37.7749,
      geo_longitude: -122.4194
    )
    raw_token = issue_token(user)

    get api_v1_transaction_path(transaction), headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "transaction" ], body.keys
    transaction_json = body.fetch("transaction")
    assert_equal transaction.to_param, transaction_json.fetch("id")
    assert_equal "expense", transaction_json.fetch("transaction_kind")
    assert_equal account.to_param, transaction_json.fetch("account_id")
    assert_equal category.to_param, transaction_json.fetch("transaction_category_id")
    assert_equal [ tag.to_param ], transaction_json.fetch("transaction_tag_ids")
    assert_equal({ "latitude" => "37.7749", "longitude" => "-122.4194" }, transaction_json.fetch("geo_location"))
    refute_includes transaction_json.keys, "user_id"
  end

  test "does not show another user's transaction" do
    user = create(:user)
    other_user = create(:user)
    transaction = create_transaction(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Food", category_type: :expense),
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-04 12:00:00"),
      source_amount_cents: 1_250,
      comment: "Other Lunch"
    )
    raw_token = issue_token(user)

    get api_v1_transaction_path(transaction), headers: json_headers(raw_token)

    assert_response :not_found
  end
```

- [ ] **Step 2: Run the integration tests and confirm RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb
```

Expected: the new show success test fails because `GET /api/v1/transactions/:id` is not routed yet.

---

### Task 2: API GREEN Implementation

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/api/v1/transactions_controller.rb`
- Test: `test/integration/api/v1/transactions_test.rb`

- [ ] **Step 1: Add `:show` to transaction routes**

Update `config/routes.rb`:

```ruby
      resources :transactions, only: [ :index, :show, :create, :update, :destroy ] do
```

- [ ] **Step 2: Add controller action**

Add this action after `index` in `app/controllers/api/v1/transactions_controller.rb`:

```ruby
  # GET /api/v1/transactions/:id
  def show
    transaction = scoped_transaction
    authorize transaction

    render json: { transaction: transaction }
  end
```

- [ ] **Step 3: Run the integration tests and confirm GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb
```

Expected: 0 failures, 0 errors.

- [ ] **Step 4: Commit the API slice**

Run:

```bash
git add config/routes.rb app/controllers/api/v1/transactions_controller.rb test/integration/api/v1/transactions_test.rb
git commit --no-gpg-sign -m "feat: add transaction show api"
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
mise exec -- bin/rubocop app/controllers/api/v1/transactions_controller.rb config/routes.rb test/integration/api/v1/transactions_test.rb
```

Expected: no offenses detected.

- [ ] **Step 4: Inspect final diff**

Run:

```bash
git status --short --branch
git diff --stat HEAD~1..HEAD
```

Expected: only this slice's route, controller, integration tests, and plan changed.
