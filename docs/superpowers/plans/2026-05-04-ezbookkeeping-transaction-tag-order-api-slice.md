# Transaction Tag Order API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow the modern Rails transaction tag update API to change `display_order`.

**Architecture:** Keep the Rails-native `PATCH /api/v1/transaction_tags/:id` endpoint as the update boundary. Permit `display_order` in the existing nested `transaction_tag` params and assign it through `TransactionTagUpdater`, so clients can reorder tags without adding ezBookkeeping legacy `.json` move routes, `success/result` envelopes, camelCase params, or old frontend compatibility.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit-scoped existing update endpoint.

---

## File Structure

- Modify `app/controllers/api/v1/transaction_tags_controller.rb`: permit `display_order` in tag params.
- Modify `app/services/transaction_tag_updater.rb`: assign `display_order` when present in update params.
- Modify `test/integration/api/v1/transaction_tags_test.rb`: extend the existing update HTTP contract to prove `display_order` updates and is returned.

---

### Task 1: API RED Test

**Files:**
- Modify: `test/integration/api/v1/transaction_tags_test.rb`

- [ ] **Step 1: Extend the existing update test**

In `test "updates a transaction tag for the token owner"`, add `display_order: "5"` to the request params:

```ruby
          display_order: "5",
```

Add/change assertions to expect display order 5:

```ruby
    assert_equal 5, tag.display_order
```

```ruby
    assert_equal 5, tag_json.fetch("display_order")
```

- [ ] **Step 2: Run the integration tests and confirm RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_tags_test.rb
```

Expected: the update test fails because `display_order` remains 1.

---

### Task 2: API GREEN Implementation

**Files:**
- Modify: `app/controllers/api/v1/transaction_tags_controller.rb`
- Modify: `app/services/transaction_tag_updater.rb`
- Test: `test/integration/api/v1/transaction_tags_test.rb`

- [ ] **Step 1: Permit `display_order`**

In `app/controllers/api/v1/transaction_tags_controller.rb`, update params:

```ruby
    @tag_params ||= params.expect(transaction_tag: [ :name, :transaction_tag_group_id, :hidden, :display_order ])
```

- [ ] **Step 2: Assign `display_order` in updater**

In `app/services/transaction_tag_updater.rb`, add:

```ruby
    tag.display_order = attributes[:display_order] if attributes.key?(:display_order)
```

- [ ] **Step 3: Run the integration tests and confirm GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_tags_test.rb
```

Expected: 0 failures, 0 errors.

- [ ] **Step 4: Commit the API slice**

Run:

```bash
git add app/controllers/api/v1/transaction_tags_controller.rb app/services/transaction_tag_updater.rb test/integration/api/v1/transaction_tags_test.rb
git commit --no-gpg-sign -m "feat: allow ordering transaction tags"
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
mise exec -- bin/rubocop app/controllers/api/v1/transaction_tags_controller.rb app/services/transaction_tag_updater.rb test/integration/api/v1/transaction_tags_test.rb
```

Expected: no offenses detected.

- [ ] **Step 4: Inspect final diff**

Run:

```bash
git status --short --branch
git diff --stat HEAD~1..HEAD
```

Expected: only this slice's controller, updater service, integration test, and plan changed.
