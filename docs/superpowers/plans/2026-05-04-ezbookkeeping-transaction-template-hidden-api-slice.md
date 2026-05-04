# Transaction Template Hidden API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow the modern Rails transaction template update API to hide/unhide templates through the existing `hidden` field.

**Architecture:** Keep the Rails-native `PATCH /api/v1/transaction_templates/:id` endpoint as the single update boundary. Permit `hidden` in the existing nested `transaction_template` params and assign it in `TransactionTemplateUpdater` using explicit boolean coercion, matching other API params that arrive as strings. Do not add ezBookkeeping legacy `.json` hide routes, `success/result` envelopes, camelCase params, or old frontend compatibility.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit-scoped existing update endpoint.

---

## File Structure

- Modify `app/controllers/api/v1/transaction_templates_controller.rb`: permit `hidden` in transaction template params.
- Modify `app/services/transaction_template_updater.rb`: assign coerced `hidden` during updates.
- Modify `test/integration/api/v1/transaction_templates_test.rb`: extend the existing update HTTP contract to prove `hidden` updates and is returned.

---

### Task 1: API RED Test

**Files:**
- Modify: `test/integration/api/v1/transaction_templates_test.rb`

- [ ] **Step 1: Extend the existing update test**

In `test "updates a transaction template for the token owner"`, add `hidden: "true"` to the request params:

```ruby
          hidden: "true",
```

Add these assertions after `template.reload` and near the response assertions:

```ruby
    assert_equal true, template.hidden
```

```ruby
    assert_equal true, template_json.fetch("hidden")
```

- [ ] **Step 2: Run the integration tests and confirm RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_templates_test.rb
```

Expected: the update test fails because `hidden` remains false.

---

### Task 2: API GREEN Implementation

**Files:**
- Modify: `app/controllers/api/v1/transaction_templates_controller.rb`
- Modify: `app/services/transaction_template_updater.rb`
- Test: `test/integration/api/v1/transaction_templates_test.rb`

- [ ] **Step 1: Permit `hidden`**

In `app/controllers/api/v1/transaction_templates_controller.rb`, add `:hidden` to `transaction_template_params`.

- [ ] **Step 2: Assign coerced `hidden`**

In `app/services/transaction_template_updater.rb`, add this key to `template_attributes`:

```ruby
      hidden: ActiveModel::Type::Boolean.new.cast(attributes[:hidden]),
```

- [ ] **Step 3: Run the integration tests and confirm GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_templates_test.rb
```

Expected: 0 failures, 0 errors.

- [ ] **Step 4: Commit the API slice**

Run:

```bash
git add app/controllers/api/v1/transaction_templates_controller.rb app/services/transaction_template_updater.rb test/integration/api/v1/transaction_templates_test.rb
git commit --no-gpg-sign -m "feat: allow hiding transaction templates"
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
mise exec -- bin/rubocop app/controllers/api/v1/transaction_templates_controller.rb app/services/transaction_template_updater.rb test/integration/api/v1/transaction_templates_test.rb
```

Expected: no offenses detected.

- [ ] **Step 4: Inspect final diff**

Run:

```bash
git status --short --branch
git diff --stat HEAD~1..HEAD
```

Expected: only this slice's controller, updater service, integration tests, and plan changed.
