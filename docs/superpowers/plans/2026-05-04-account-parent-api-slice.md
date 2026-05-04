# Account Parent API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow the modern accounts API to create child accounts under a current-user parent account.

**Architecture:** Keep `POST /api/v1/accounts` as the canonical create boundary. Permit snake_case `parent_account_id`, resolve it through `current_user.accounts.kept`, assign it before calling `AccountCreator`, and compute `display_order` among the selected parent's children. Do not add ezBookkeeping legacy routes, camelCase params, or compatibility wrappers.

**Tech Stack:** Rails 8.1 controller params, existing `AccountCreator`, Minitest integration tests.

---

### Task 1: API Contract Tests

**Files:**
- Modify: `test/integration/api/v1/accounts_test.rb`

- [ ] **Step 1: Add child account create test**

Add a test that creates a parent account and an existing child, then posts:

```ruby
post api_v1_accounts_path,
  params: {
    account: {
      name: "Vacation Savings",
      account_category: "savings_account",
      account_structure: "single_account",
      parent_account_id: parent.to_param,
      icon_key: "2",
      color_hex: "#22c55e",
      currency_code: "usd",
      opening_balance_cents: "12300",
      comment: "Trip fund"
    }
  },
  headers: json_headers(raw_token),
  as: :json
```

Expect the created account to have `parent_account == parent`, `display_order == 2`, and response JSON `parent_account_id == parent.to_param`.

- [ ] **Step 2: Add unavailable parent test**

Post `parent_account_id` for another user's account. Expect `422`, no account creation, and an error mentioning parent account.

- [ ] **Step 3: Run focused test to verify RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb`

Expected: FAIL because `parent_account_id` is not permitted or assigned.

### Task 2: Implementation

**Files:**
- Modify: `app/controllers/api/v1/accounts_controller.rb`

- [ ] **Step 1: Permit `parent_account_id`**

Add `:parent_account_id` to `account_params`.

- [ ] **Step 2: Resolve parent through current user**

Add a private `parent_account_for(account)` helper that returns `nil` for blank `parent_account_id`, resolves prefixed IDs through `current_user.accounts.kept`, and adds `account.errors.add(:parent_account, "is unavailable")` when the parent is not in scope.

- [ ] **Step 3: Include parent and sibling display order in create attributes**

Build a temporary account from permitted attributes, assign `parent_account`, and pass attributes with `parent_account:` and `display_order: next_display_order(parent_account)` into `AccountCreator` only when no parent error exists.

- [ ] **Step 4: Run focused test to verify GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb`

Expected: PASS.

### Task 3: Verification and Commit

**Files:**
- All touched files from Tasks 1-2.

- [ ] **Step 1: Run full test suite**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 2: Run focused RuboCop**

Run: `mise exec -- bin/rubocop app/controllers/api/v1/accounts_controller.rb test/integration/api/v1/accounts_test.rb`

Expected: PASS with no offenses.

- [ ] **Step 3: Commit**

Run:

```bash
git add app/controllers/api/v1/accounts_controller.rb test/integration/api/v1/accounts_test.rb docs/superpowers/plans/2026-05-04-account-parent-api-slice.md
git commit --no-gpg-sign -m "feat: support child account creation via api"
```
