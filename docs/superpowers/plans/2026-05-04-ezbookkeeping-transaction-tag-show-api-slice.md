# Transaction Tag Show API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modern Rails API endpoint for fetching one current-user transaction tag by ID.

**Architecture:** Extend the existing Rails-native `api/v1/transaction_tags` resource with the standard `show` action. Reuse the existing `scoped_tag` helper and `TransactionTag#as_json` response shape so ownership scoping, discarded filtering, and JSON fields stay consistent with index/update/delete. Do not add ezBookkeeping legacy `.json` routes, `success/result` envelopes, camelCase params, or old frontend compatibility.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit, existing `TransactionTag#as_json`.

---

## File Structure

- Modify `config/routes.rb`: include `:show` in `api/v1` transaction tag routes.
- Modify `app/controllers/api/v1/transaction_tags_controller.rb`: add `show` action that renders `{ transaction_tag: scoped_tag.as_json }`.
- Modify `app/policies/transaction_tag_policy.rb`: allow owner-scoped transaction tag show authorization.
- Modify `test/integration/api/v1/transaction_tags_test.rb`: add HTTP contract tests for success and current-user scoping.

---

### Task 1: API RED Tests

**Files:**
- Modify: `test/integration/api/v1/transaction_tags_test.rb`

- [ ] **Step 1: Add show endpoint tests**

Add these tests after `test "lists only the token owner's kept transaction tags"` in `test/integration/api/v1/transaction_tags_test.rb`:

```ruby
  test "shows one transaction tag for the token owner" do
    user = create(:user)
    group = create_tag_group(user: user, name: "Food", display_order: 1)
    tag = create_tag(user: user, name: "Meals", display_order: 1, transaction_tag_group: group)
    raw_token = issue_token(user)

    get api_v1_transaction_tag_path(tag), headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "transaction_tag" ], body.keys
    tag_json = body.fetch("transaction_tag")
    assert_equal tag.to_param, tag_json.fetch("id")
    assert_equal "Meals", tag_json.fetch("name")
    assert_equal group.to_param, tag_json.fetch("transaction_tag_group_id")
    assert_equal 1, tag_json.fetch("display_order")
    assert_equal false, tag_json.fetch("hidden")
    refute_includes tag_json.keys, "user_id"
  end

  test "does not show another user's transaction tag" do
    user = create(:user)
    other_user = create(:user)
    tag = create_tag(user: other_user, name: "Other", display_order: 1)
    raw_token = issue_token(user)

    get api_v1_transaction_tag_path(tag), headers: json_headers(raw_token)

    assert_response :not_found
  end
```

- [ ] **Step 2: Run the integration tests and confirm RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_tags_test.rb
```

Expected: the new show success test fails because `GET /api/v1/transaction_tags/:id` is not routed yet.

---

### Task 2: API GREEN Implementation

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/api/v1/transaction_tags_controller.rb`
- Modify: `app/policies/transaction_tag_policy.rb`
- Test: `test/integration/api/v1/transaction_tags_test.rb`

- [ ] **Step 1: Add `:show` to transaction tag routes**

Update `config/routes.rb`:

```ruby
      resources :transaction_tags, only: [ :index, :show, :create, :update, :destroy ]
```

- [ ] **Step 2: Add policy method**

Add this method to `app/policies/transaction_tag_policy.rb`:

```ruby
  def show? = owns_record?
```

- [ ] **Step 3: Add controller action**

Add this action after `index` in `app/controllers/api/v1/transaction_tags_controller.rb`:

```ruby
  # GET /api/v1/transaction_tags/:id
  def show
    tag = scoped_tag
    authorize tag

    render json: { transaction_tag: tag.as_json }
  end
```

- [ ] **Step 4: Run the integration tests and confirm GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_tags_test.rb
```

Expected: 0 failures, 0 errors.

- [ ] **Step 5: Commit the API slice**

Run:

```bash
git add config/routes.rb app/controllers/api/v1/transaction_tags_controller.rb app/policies/transaction_tag_policy.rb test/integration/api/v1/transaction_tags_test.rb
git commit --no-gpg-sign -m "feat: add transaction tag show api"
```

---

### Task 3: Verification

**Files:**
- Verify all changed files

- [ ] **Step 1: Run focused tests**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_tags_test.rb
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
mise exec -- bin/rubocop app/controllers/api/v1/transaction_tags_controller.rb app/policies/transaction_tag_policy.rb config/routes.rb test/integration/api/v1/transaction_tags_test.rb
```

Expected: no offenses detected.

- [ ] **Step 4: Inspect final diff**

Run:

```bash
git status --short --branch
git diff --stat HEAD~1..HEAD
```

Expected: only this slice's route, controller, policy, integration tests, and plan changed.
