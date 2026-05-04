# Transaction Template Show API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modern Rails API endpoint for fetching one current-user transaction template by ID.

**Architecture:** Extend the existing Rails-native `api/v1/transaction_templates` resource with the standard `show` action. Reuse the existing `scoped_template` helper and `TransactionTemplate#as_json` response shape so ownership scoping, discarded filtering, and JSON fields stay consistent with index/update/delete. Do not add ezBookkeeping legacy `.json` routes, `success/result` envelopes, camelCase params, or old frontend compatibility.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit, existing `TransactionTemplate#as_json`.

---

## File Structure

- Modify `config/routes.rb`: include `:show` in `api/v1` transaction template routes.
- Modify `app/controllers/api/v1/transaction_templates_controller.rb`: add `show` action that renders `{ transaction_template: scoped_template.as_json }`.
- Modify `app/policies/transaction_template_policy.rb`: allow owner-scoped transaction template show authorization.
- Modify `test/integration/api/v1/transaction_templates_test.rb`: add HTTP contract tests for success and current-user scoping.

---

### Task 1: API RED Tests

**Files:**
- Modify: `test/integration/api/v1/transaction_templates_test.rb`

- [ ] **Step 1: Add show endpoint tests**

Add these tests after `test "lists only the token owner's kept transaction templates"` in `test/integration/api/v1/transaction_templates_test.rb`:

```ruby
  test "shows one transaction template for the token owner" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Bills", category_type: :expense)
    tag = create_tag(user: user, name: "Rent")
    template = create_template(
      user: user,
      account: account,
      category: category,
      name: "Rent",
      template_kind: :scheduled,
      display_order: 1,
      schedule_frequency: :monthly,
      schedule_rule: "-1",
      schedule_start_on: Date.new(2026, 5, 1),
      scheduled_at_minutes: 540,
      timezone_utc_offset_minutes: 480,
      tags: [ tag ]
    )
    raw_token = issue_token(user)

    get api_v1_transaction_template_path(template), headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "transaction_template" ], body.keys
    template_json = body.fetch("transaction_template")
    assert_equal template.to_param, template_json.fetch("id")
    assert_equal "Rent", template_json.fetch("name")
    assert_equal "scheduled", template_json.fetch("template_kind")
    assert_equal "expense", template_json.fetch("transaction_kind")
    assert_equal account.to_param, template_json.fetch("account_id")
    assert_equal category.to_param, template_json.fetch("transaction_category_id")
    assert_equal "monthly", template_json.fetch("schedule_frequency")
    assert_equal "-1", template_json.fetch("schedule_rule")
    assert_equal "2026-05-01", template_json.fetch("schedule_start_on")
    assert_equal [ tag.to_param ], template_json.fetch("transaction_tag_ids")
    refute_includes template_json.keys, "user_id"
  end

  test "does not show another user's transaction template" do
    user = create(:user)
    other_user = create(:user)
    template = create_template(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Bills", category_type: :expense),
      name: "Other Rent",
      template_kind: :scheduled,
      display_order: 1
    )
    raw_token = issue_token(user)

    get api_v1_transaction_template_path(template), headers: json_headers(raw_token)

    assert_response :not_found
  end
```

- [ ] **Step 2: Run the integration tests and confirm RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_templates_test.rb
```

Expected: the new show success test fails because `GET /api/v1/transaction_templates/:id` is not routed yet.

---

### Task 2: API GREEN Implementation

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/api/v1/transaction_templates_controller.rb`
- Modify: `app/policies/transaction_template_policy.rb`
- Test: `test/integration/api/v1/transaction_templates_test.rb`

- [ ] **Step 1: Add `:show` to transaction template routes**

Update `config/routes.rb`:

```ruby
      resources :transaction_templates, only: [ :index, :show, :create, :update, :destroy ]
```

- [ ] **Step 2: Add policy method**

Add this method to `app/policies/transaction_template_policy.rb`:

```ruby
  def show? = user.present? && record.user_id == user.id
```

- [ ] **Step 3: Add controller action**

Add this action after `index` in `app/controllers/api/v1/transaction_templates_controller.rb`:

```ruby
  # GET /api/v1/transaction_templates/:id
  def show
    template = scoped_template
    authorize template

    render json: { transaction_template: template.as_json }
  end
```

- [ ] **Step 4: Run the integration tests and confirm GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_templates_test.rb
```

Expected: 0 failures, 0 errors.

- [ ] **Step 5: Commit the API slice**

Run:

```bash
git add config/routes.rb app/controllers/api/v1/transaction_templates_controller.rb app/policies/transaction_template_policy.rb test/integration/api/v1/transaction_templates_test.rb
git commit --no-gpg-sign -m "feat: add transaction template show api"
```

---

### Task 3: Verification

**Files:**
- Verify all changed files

- [ ] **Step 1: Run focused tests**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_templates_test.rb
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
mise exec -- bin/rubocop app/controllers/api/v1/transaction_templates_controller.rb app/policies/transaction_template_policy.rb config/routes.rb test/integration/api/v1/transaction_templates_test.rb
```

Expected: no offenses detected.

- [ ] **Step 4: Inspect final diff**

Run:

```bash
git status --short --branch
git diff --stat HEAD~1..HEAD
```

Expected: only this slice's route, controller, policy, integration tests, and plan changed.
