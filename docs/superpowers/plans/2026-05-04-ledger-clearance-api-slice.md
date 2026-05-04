# Ledger Clearance API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a token-authenticated API endpoint for clearing the current user's ledger data.

**Architecture:** Use `resources :ledger_clearances, only: :create` under `api/v1` because each request creates a destructive clearance event. Reuse `LedgerClearance` and `LedgerClearancePolicy`, require the current password at the HTTP boundary like the existing HTML form, and return explicit JSON errors for invalid password or scope. Do not add ezBookkeeping legacy `.json` routes, camelCase params, or compatibility envelopes.

**Tech Stack:** Rails 8.1 controller params, HTTP token auth, Pundit, Minitest integration tests.

---

### Task 1: API Contract Tests

**Files:**
- Create: `test/integration/api/v1/ledger_clearances_test.rb`

- [x] **Step 1: Add transactions scope test**

Post `ledger_clearance: { clearance_scope: "transactions", current_password: "password123" }` with token auth. Expect `201`, response `{ ledger_clearance: { clearance_scope: "transactions" } }`, user's transaction discarded, account balance reset to `0`, and category kept.

- [x] **Step 2: Add all scope test**

Post `ledger_clearance: { clearance_scope: "all", current_password: "password123" }`. Expect `201`, response `{ ledger_clearance: { clearance_scope: "all" } }`, user's transaction/account/category discarded.

- [x] **Step 3: Add rejection tests**

Cover wrong password with `422` and unchanged data. Cover invalid `clearance_scope` with `422`, an error mentioning clearance scope, and unchanged data.

- [x] **Step 4: Run focused test to verify RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/ledger_clearances_test.rb`

Expected: FAIL with missing route/helper or controller because the API resource does not exist yet.

### Task 2: Implementation

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/api/v1/ledger_clearances_controller.rb`

- [x] **Step 1: Add API route**

Inside `namespace :api do namespace :v1 do`, add:

```ruby
resources :ledger_clearances, only: :create
```

- [x] **Step 2: Add API controller**

Create `app/controllers/api/v1/ledger_clearances_controller.rb`:

```ruby
class Api::V1::LedgerClearancesController < ApiController
  # POST /api/v1/ledger_clearances
  def create
    authorize :ledger_clearance
    permitted = ledger_clearance_params

    unless current_user.valid_password?(permitted[:current_password])
      render json: { errors: [ "Current password is incorrect" ] }, status: :unprocessable_content
      return
    end

    case permitted[:clearance_scope]
    when "transactions"
      LedgerClearance.new.clear_transactions(user: current_user)
      render json: { ledger_clearance: { clearance_scope: "transactions" } }, status: :created
    when "all"
      LedgerClearance.new.clear_all_data(user: current_user)
      render json: { ledger_clearance: { clearance_scope: "all" } }, status: :created
    else
      render json: { errors: [ "Clearance scope must be transactions or all" ] }, status: :unprocessable_content
    end
  end

  private

  def ledger_clearance_params
    params.expect(ledger_clearance: [ :clearance_scope, :current_password ])
  end
end
```

- [x] **Step 3: Run focused test to verify GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/ledger_clearances_test.rb`

Expected: PASS.

### Task 3: Verification and Commit

**Files:**
- All touched files from Tasks 1-2.

- [x] **Step 1: Run full test suite**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [x] **Step 2: Run focused RuboCop**

Run: `mise exec -- bin/rubocop config/routes.rb app/controllers/api/v1/ledger_clearances_controller.rb test/integration/api/v1/ledger_clearances_test.rb`

Expected: PASS with no offenses.

- [x] **Step 3: Commit**

Run:

```bash
git add config/routes.rb app/controllers/api/v1/ledger_clearances_controller.rb test/integration/api/v1/ledger_clearances_test.rb docs/superpowers/plans/2026-05-04-ledger-clearance-api-slice.md
git commit --no-gpg-sign -m "feat: add ledger clearance api"
```
