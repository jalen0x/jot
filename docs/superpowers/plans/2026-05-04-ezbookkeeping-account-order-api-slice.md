# Account Order API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow the modern Rails account update API to change `display_order`.

**Architecture:** Keep the Rails-native `PATCH /api/v1/accounts/:id` endpoint as the update boundary. Permit `display_order` in the existing nested `account` params so clients can reorder accounts without adding ezBookkeeping legacy `.json` move routes, `success/result` envelopes, camelCase params, or old frontend compatibility.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit-scoped existing update endpoint.

---

## File Structure

- Modify `app/controllers/api/v1/accounts_controller.rb`: permit `display_order` in account update params.
- Modify `test/integration/api/v1/accounts_test.rb`: extend the existing update HTTP contract to prove `display_order` updates and is returned.

---

### Task 1: API RED Test

**Files:**
- Modify: `test/integration/api/v1/accounts_test.rb`

- [ ] **Step 1: Extend the existing update test**

In `test "updates an account for the token owner"`, add `display_order: "5"` to the request params:

```ruby
          display_order: "5",
```

Add assertions to expect display order 5:

```ruby
    assert_equal 5, account.display_order
```

```ruby
    assert_equal 5, account_json.fetch("display_order")
```

- [ ] **Step 2: Run the integration tests and confirm RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb
```

Expected: the update test fails because `display_order` remains 1.

---

### Task 2: API GREEN Implementation

**Files:**
- Modify: `app/controllers/api/v1/accounts_controller.rb`
- Test: `test/integration/api/v1/accounts_test.rb`

- [ ] **Step 1: Permit `display_order`**

In `app/controllers/api/v1/accounts_controller.rb`, add `:display_order` to `account_update_params`.

- [ ] **Step 2: Run the integration tests and confirm GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb
```

Expected: 0 failures, 0 errors.

- [ ] **Step 3: Commit the API slice**

Run:

```bash
git add app/controllers/api/v1/accounts_controller.rb test/integration/api/v1/accounts_test.rb
git commit --no-gpg-sign -m "feat: allow ordering accounts"
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
mise exec -- bin/rubocop app/controllers/api/v1/accounts_controller.rb test/integration/api/v1/accounts_test.rb
```

Expected: no offenses detected.

- [ ] **Step 4: Inspect final diff**

Run:

```bash
git status --short --branch
git diff --stat HEAD~1..HEAD
```

Expected: only this slice's controller, integration test, and plan changed.
