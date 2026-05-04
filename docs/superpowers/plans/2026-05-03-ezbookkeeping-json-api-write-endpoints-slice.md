# ezBookkeeping JSON API Write Endpoints Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add token-authenticated JSON create endpoints for transaction categories and transactions.

**Architecture:** Extend the existing Rails-native `api/v1` boundary without adding legacy ezBookkeeping `.json` path compatibility yet. Controllers stay thin, authorize through Pundit, scope all user-owned IDs through `current_user`, and return explicit top-level JSON keys. Transaction creation delegates to `TransactionRecorder` so balances, category rules, and tag assignment stay centralized.

**Tech Stack:** Rails 8.1, Pundit, ApiToken bearer auth, existing `TransactionCategory`, `Transaction`, and `TransactionRecorder`, Minitest integration/service tests.

---

## File Structure

- Modify `config/routes.rb`: allow `create` for API transaction categories and transactions.
- Modify `app/controllers/api/v1/transaction_categories_controller.rb`: add `create` with current-user parent category scoping and explicit error JSON.
- Modify `app/controllers/api/v1/transactions_controller.rb`: add `create` through `TransactionRecorder` and explicit error JSON.
- Modify `app/services/transaction_recorder.rb`: load tag IDs with `find` so prefixed API IDs and numeric UI IDs both work.
- Modify `test/integration/api/v1/transaction_categories_test.rb`: category create success and parent scoping failure.
- Modify `test/integration/api/v1/transactions_test.rb`: transaction create success through recorder and unavailable user-owned IDs failure.
- Modify `test/services/transaction_recorder_test.rb`: prefixed tag IDs are accepted by the shared recorder.

---

### Task 1: Add `POST /api/v1/transaction_categories`

**Files:**
- Modify: `test/integration/api/v1/transaction_categories_test.rb`
- Modify: `app/controllers/api/v1/transaction_categories_controller.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing category API tests**

Add tests proving a bearer token can create a category with JSON params and receives `201` plus `{ transaction_category: ... }`, and that a parent category owned by another user is rejected with `422` and an error without creating a category.

- [ ] **Step 2: Run category API tests RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/transaction_categories_test.rb`

Expected: FAIL because POST is not routed or controller action is missing.

- [ ] **Step 3: Implement category create**

Add `create` to the route and controller. Use `current_user.transaction_categories.build`, resolve optional `parent_category_id` through `current_user.transaction_categories.kept.find`, set the next display order under that parent, and render `status: :created` or `status: :unprocessable_content` with `{ errors: category.errors.full_messages }`.

- [ ] **Step 4: Run category API tests GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/transaction_categories_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit category write endpoint**

```bash
git add config/routes.rb app/controllers/api/v1/transaction_categories_controller.rb test/integration/api/v1/transaction_categories_test.rb
git commit --no-gpg-sign -m "feat: add transaction category create api"
```

---

### Task 2: Add `POST /api/v1/transactions`

**Files:**
- Modify: `test/integration/api/v1/transactions_test.rb`
- Modify: `test/services/transaction_recorder_test.rb`
- Modify: `app/controllers/api/v1/transactions_controller.rb`
- Modify: `app/services/transaction_recorder.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing transaction API and recorder tests**

Add tests proving a bearer token can create an expense transaction with prefixed account/category/tag IDs, receives `201` plus `{ transaction: ... }`, the account balance changes through `TransactionRecorder`, and another user's account/category IDs return `422` without creating a transaction. Add a service test proving `TransactionRecorder` accepts a prefixed tag ID.

- [ ] **Step 2: Run transaction tests RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb test/services/transaction_recorder_test.rb`

Expected: FAIL because POST is not routed or prefixed tag IDs are not accepted.

- [ ] **Step 3: Implement transaction create and prefixed tag handling**

Add `create` to the API route and controller. Delegate to `TransactionRecorder.new.record_transaction(user: current_user, attributes: transaction_params, tag_ids: transaction_tag_ids)`. In `TransactionRecorder#find_tags`, resolve each tag with `user.transaction_tags.kept.find(id)` so `tag_...` and numeric IDs both work, preserving the existing unavailable-tags error behavior.

- [ ] **Step 4: Run transaction tests GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb test/services/transaction_recorder_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit transaction write endpoint**

```bash
git add config/routes.rb app/controllers/api/v1/transactions_controller.rb app/services/transaction_recorder.rb test/integration/api/v1/transactions_test.rb test/services/transaction_recorder_test.rb
git commit --no-gpg-sign -m "feat: add transaction create api"
```

---

### Task 3: Verify JSON API write endpoints slice

- [ ] **Step 1: Run focused API tests**

Run: `mise exec -- bin/rails test test/integration/api/v1/transaction_categories_test.rb test/integration/api/v1/transactions_test.rb test/integration/api/v1/accounts_test.rb test/integration/api/authentication_test.rb test/integration/api/content_negotiation_test.rb test/services/transaction_recorder_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run lint for touched files**

Run: `mise exec -- bin/rubocop app/controllers/api/v1/transaction_categories_controller.rb app/controllers/api/v1/transactions_controller.rb app/services/transaction_recorder.rb test/integration/api/v1/transaction_categories_test.rb test/integration/api/v1/transactions_test.rb test/services/transaction_recorder_test.rb config/routes.rb`

Expected: PASS.

- [ ] **Step 4: Check git status**

Run: `git status --short`

Expected: clean working tree.

---

## Self-Review

- Spec coverage: extends the Phase 8 JSON API seam with write access for the same resources already exposed by read endpoints, while keeping API auth, content negotiation, current-user scoping, and top-level response keys.
- Scope control: does not implement legacy source paths, update/delete endpoints, batch mutation, pagination, pictures, geo location, or MCP support. MCP is excluded from the Rails rewrite scope.
- Placeholder scan: no TODO/TBD placeholders remain.
- Type consistency: route helpers, controller names, response keys, and params consistently use `transaction_category`, `transaction_categories`, `transaction`, and `transactions`.
