# Account Show API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modern Rails API endpoint for fetching one current-user account by ID.

**Architecture:** Extend the existing Rails-native `api/v1/accounts` resource with the standard `show` action. Reuse the existing `scoped_account` helper and `Account#as_json` response shape so ownership scoping, discarded filtering, and JSON fields stay consistent with index/update/delete. Do not add ezBookkeeping legacy `.json` routes, `success/result` envelopes, camelCase params, or old frontend compatibility.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit, existing `Account#as_json`.

---

## File Structure

- Modify `config/routes.rb`: include `:show` in `api/v1` account routes.
- Modify `app/controllers/api/v1/accounts_controller.rb`: add `show` action that renders `{ account: scoped_account }`.
- Modify `app/policies/account_policy.rb`: allow owner-scoped account show authorization.
- Modify `test/integration/api/v1/accounts_test.rb`: add HTTP contract tests for success and current-user scoping.

---

### Task 1: API RED Tests

**Files:**
- Modify: `test/integration/api/v1/accounts_test.rb`

- [ ] **Step 1: Add show endpoint tests**

Add these tests after `test "lists only the token owner's kept accounts"` in `test/integration/api/v1/accounts_test.rb`:

```ruby
  test "shows one account for the token owner" do
    user = create(:user)
    account = create_account(user: user, name: "Checking", balance_cents: 12_300)
    raw_token = issue_token(user)

    get api_v1_account_path(account), headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "account" ], body.keys
    account_json = body.fetch("account")
    assert_equal account.to_param, account_json.fetch("id")
    assert_equal "Checking", account_json.fetch("name")
    assert_equal "cash", account_json.fetch("account_category")
    assert_equal "single_account", account_json.fetch("account_structure")
    assert_equal "USD", account_json.fetch("currency_code")
    assert_equal 12_300, account_json.fetch("balance_cents")
    assert_equal false, account_json.fetch("hidden")
    refute_includes account_json.keys, "user_id"
  end

  test "does not show another user's account" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: other_user, name: "Other Checking", balance_cents: 50_000)
    raw_token = issue_token(user)

    get api_v1_account_path(account), headers: json_headers(raw_token)

    assert_response :not_found
  end
```

- [ ] **Step 2: Run the integration tests and confirm RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb
```

Expected: the new show success test fails because `GET /api/v1/accounts/:id` is not routed yet.

---

### Task 2: API GREEN Implementation

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/api/v1/accounts_controller.rb`
- Modify: `app/policies/account_policy.rb`
- Test: `test/integration/api/v1/accounts_test.rb`

- [ ] **Step 1: Add `:show` to account routes**

Update `config/routes.rb`:

```ruby
      resources :accounts, only: [ :index, :show, :create, :update, :destroy ]
```

- [ ] **Step 2: Add policy method**

Add this method to `app/policies/account_policy.rb`:

```ruby
  def show? = owns_record?
```

- [ ] **Step 3: Add controller action**

Add this action after `index` in `app/controllers/api/v1/accounts_controller.rb`:

```ruby
  # GET /api/v1/accounts/:id
  def show
    account = scoped_account
    authorize account

    render json: { account: account }
  end
```

- [ ] **Step 4: Run the integration tests and confirm GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb
```

Expected: 0 failures, 0 errors.

- [ ] **Step 5: Commit the API slice**

Run:

```bash
git add config/routes.rb app/controllers/api/v1/accounts_controller.rb app/policies/account_policy.rb test/integration/api/v1/accounts_test.rb
git commit --no-gpg-sign -m "feat: add account show api"
```

---

### Task 3: Verification

**Files:**
- Verify all changed files

- [ ] **Step 1: Run focused tests**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb
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
mise exec -- bin/rubocop app/controllers/api/v1/accounts_controller.rb app/policies/account_policy.rb config/routes.rb test/integration/api/v1/accounts_test.rb
```

Expected: no offenses detected.

- [ ] **Step 4: Inspect final diff**

Run:

```bash
git status --short --branch
git diff --stat HEAD~1..HEAD
```

Expected: only this slice's route, controller, policy, integration tests, and plan changed.
