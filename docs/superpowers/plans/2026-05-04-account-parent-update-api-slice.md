# Account Parent Update API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow the modern account update API to move accounts under a parent account or clear the parent.

**Architecture:** Keep `PATCH /api/v1/accounts/:id` as the canonical account update boundary. Permit snake_case `parent_account_id` only on the existing nested `account` params, resolve non-blank values through the token owner's kept accounts, allow blank values to clear the parent, and reject self-parenting. Do not add ezBookkeeping legacy routes, camelCase params, or compatibility wrappers.

**Tech Stack:** Rails 8.1 controller params, Active Record, Minitest integration tests.

---

### Task 1: API Contract Tests

**Files:**
- Modify: `test/integration/api/v1/accounts_test.rb`

- [x] **Step 1: Add update-to-parent test**

Patch an existing account with `parent_account_id: parent.to_param`. Expect `200`, persisted `parent_account == parent`, and response JSON `parent_account_id == parent.to_param`.

- [x] **Step 2: Add clear-parent test**

Start with a child account, patch with `parent_account_id: ""`. Expect `200`, persisted `parent_account_id == nil`, and response JSON `parent_account_id == nil`.

- [x] **Step 3: Add self-parent rejection test**

Patch an account with `parent_account_id: account.to_param`. Expect `422`, unchanged parent, and an error mentioning parent account.

- [x] **Step 4: Add cross-user parent rejection test**

Patch an account with another user's `parent_account_id`. Expect `422`, unchanged parent, and an error mentioning parent account.

- [x] **Step 5: Run focused test to verify RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb`

Expected: FAIL because `parent_account_id` is not permitted or assigned on update.

### Task 2: Implementation

**Files:**
- Modify: `app/controllers/api/v1/accounts_controller.rb`

- [x] **Step 1: Permit `parent_account_id` on update**

Add `:parent_account_id` to `account_update_params`.

- [x] **Step 2: Assign parent before save when key is present**

Change `update` to assign normal attributes excluding `parent_account_id`, then call a helper only when `account_update_params.key?(:parent_account_id)`.

- [x] **Step 3: Resolve parent safely**

Implement helper behavior:

```ruby
return nil if parent_account_id.blank?
parent = current_user.accounts.kept.find(Account.decode_prefix_id(parent_account_id) || parent_account_id)
if parent == account
  account.errors.add(:parent_account, "cannot be itself")
  return nil
end
parent
```

Rescue unavailable parent with `account.errors.add(:parent_account, "is unavailable")` and return `nil`. If errors exist, render `422` without saving.

- [x] **Step 4: Run focused test to verify GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb`

Expected: PASS.

### Task 3: Verification and Commit

**Files:**
- All touched files from Tasks 1-2.

- [x] **Step 1: Run full test suite**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [x] **Step 2: Run focused RuboCop**

Run: `mise exec -- bin/rubocop app/controllers/api/v1/accounts_controller.rb test/integration/api/v1/accounts_test.rb`

Expected: PASS with no offenses.

- [x] **Step 3: Commit**

Run:

```bash
git add app/controllers/api/v1/accounts_controller.rb test/integration/api/v1/accounts_test.rb docs/superpowers/plans/2026-05-04-account-parent-update-api-slice.md
git commit --no-gpg-sign -m "feat: support account parent updates via api"
```
