# Transaction Category Show API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modern Rails API endpoint for fetching one current-user transaction category by ID.

**Architecture:** Extend the existing Rails-native `api/v1/transaction_categories` resource with the standard `show` action. Reuse the existing `scoped_category` helper and `TransactionCategory#as_json` response shape so ownership scoping, discarded filtering, and JSON fields stay consistent with index/update/delete. Do not add ezBookkeeping legacy `.json` routes, `success/result` envelopes, camelCase params, or old frontend compatibility.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit, existing `TransactionCategory#as_json`.

---

## File Structure

- Modify `config/routes.rb`: include `:show` in `api/v1` transaction category routes.
- Modify `app/controllers/api/v1/transaction_categories_controller.rb`: add `show` action that renders `{ transaction_category: scoped_category.as_json }`.
- Modify `app/policies/transaction_category_policy.rb`: allow owner-scoped transaction category show authorization.
- Modify `test/integration/api/v1/transaction_categories_test.rb`: add HTTP contract tests for success and current-user scoping.

---

### Task 1: API RED Tests

**Files:**
- Modify: `test/integration/api/v1/transaction_categories_test.rb`

- [ ] **Step 1: Add show endpoint tests**

Add these tests after `test "lists only the token owner's kept transaction categories"` in `test/integration/api/v1/transaction_categories_test.rb`:

```ruby
  test "shows one transaction category for the token owner" do
    user = create(:user)
    parent = create_category(user: user, name: "Food", category_type: :expense, display_order: 1)
    category = create_category(user: user, name: "Dining", category_type: :expense, parent_category: parent, display_order: 2)
    raw_token = issue_token(user)

    get api_v1_transaction_category_path(category), headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "transaction_category" ], body.keys
    category_json = body.fetch("transaction_category")
    assert_equal category.to_param, category_json.fetch("id")
    assert_equal "Dining", category_json.fetch("name")
    assert_equal "expense", category_json.fetch("category_type")
    assert_equal parent.to_param, category_json.fetch("parent_category_id")
    assert_equal 2, category_json.fetch("display_order")
    assert_equal false, category_json.fetch("hidden")
    refute_includes category_json.keys, "user_id"
  end

  test "does not show another user's transaction category" do
    user = create(:user)
    other_user = create(:user)
    category = create_category(user: other_user, name: "Other", category_type: :expense, display_order: 1)
    raw_token = issue_token(user)

    get api_v1_transaction_category_path(category), headers: json_headers(raw_token)

    assert_response :not_found
  end
```

- [ ] **Step 2: Run the integration tests and confirm RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_categories_test.rb
```

Expected: the new show success test fails because `GET /api/v1/transaction_categories/:id` is not routed yet.

---

### Task 2: API GREEN Implementation

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/api/v1/transaction_categories_controller.rb`
- Modify: `app/policies/transaction_category_policy.rb`
- Test: `test/integration/api/v1/transaction_categories_test.rb`

- [ ] **Step 1: Add `:show` to transaction category routes**

Update `config/routes.rb`:

```ruby
      resources :transaction_categories, only: [ :index, :show, :create, :update, :destroy ]
```

- [ ] **Step 2: Add policy method**

Add this method to `app/policies/transaction_category_policy.rb`:

```ruby
  def show? = owns_record?
```

- [ ] **Step 3: Add controller action**

Add this action after `index` in `app/controllers/api/v1/transaction_categories_controller.rb`:

```ruby
  # GET /api/v1/transaction_categories/:id
  def show
    category = scoped_category
    authorize category

    render json: { transaction_category: category.as_json }
  end
```

- [ ] **Step 4: Run the integration tests and confirm GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_categories_test.rb
```

Expected: 0 failures, 0 errors.

- [ ] **Step 5: Commit the API slice**

Run:

```bash
git add config/routes.rb app/controllers/api/v1/transaction_categories_controller.rb app/policies/transaction_category_policy.rb test/integration/api/v1/transaction_categories_test.rb
git commit --no-gpg-sign -m "feat: add transaction category show api"
```

---

### Task 3: Verification

**Files:**
- Verify all changed files

- [ ] **Step 1: Run focused tests**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_categories_test.rb
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
mise exec -- bin/rubocop app/controllers/api/v1/transaction_categories_controller.rb app/policies/transaction_category_policy.rb config/routes.rb test/integration/api/v1/transaction_categories_test.rb
```

Expected: no offenses detected.

- [ ] **Step 4: Inspect final diff**

Run:

```bash
git status --short --branch
git diff --stat HEAD~1..HEAD
```

Expected: only this slice's route, controller, policy, integration tests, and plan changed.
