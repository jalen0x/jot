# Account Reconciliation Statement API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose the existing `AccountReconciliation` service through a Rails-native JSON API resource.

**Architecture:** Add a nested singular resource, `GET /api/v1/accounts/:account_id/reconciliation_statement`, because a reconciliation statement is identified by an account plus date filters. Keep the controller thin: authenticate API token, scope the account through the current user's kept accounts, coerce ISO date params, call `AccountReconciliation`, and render a top-level `reconciliation_statement` object. Do not add ezBookkeeping legacy `.json` paths, camelCase params, or `success/result` envelopes.

**Tech Stack:** Rails 8.1 routes/controllers, Pundit, Minitest integration tests, existing `AccountReconciliation` service.

---

### Task 1: API Contract Tests

**Files:**
- Modify: `test/integration/api/v1/accounts_test.rb`

- [ ] **Step 1: Add success and boundary tests**

Add tests covering:

```ruby
get api_v1_account_reconciliation_statement_path(account),
  params: { start_date: "2026-05-03", end_date: "2026-05-03" },
  headers: json_headers(raw_token)
```

Expected JSON top-level key:

```json
{
  "reconciliation_statement": {
    "account_id": "acct_...",
    "start_date": "2026-05-03",
    "end_date": "2026-05-03",
    "opening_balance_cents": 5000,
    "inflow_cents": 2000,
    "outflow_cents": 1200,
    "closing_balance_cents": 5800,
    "transaction_ids": ["txn_...", "txn_..."]
  }
}
```

Also test another user's account returns `404`, and invalid ISO date returns `422` with an `errors` array.

- [ ] **Step 2: Run focused test to verify RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb`

Expected: FAIL with missing `api_v1_account_reconciliation_statement_path` route helper.

### Task 2: Resource Route, Controller, and Policy

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/api/v1/account_reconciliation_statements_controller.rb`
- Create: `app/policies/account_reconciliation_statement_policy.rb`

- [ ] **Step 1: Add nested singular route**

Change the API accounts route to:

```ruby
resources :accounts, only: [ :index, :show, :create, :update, :destroy ] do
  resource :reconciliation_statement, only: :show, controller: "account_reconciliation_statements"
end
```

- [ ] **Step 2: Add policy**

Create:

```ruby
class AccountReconciliationStatementPolicy < ApplicationPolicy
  def show? = user.present?
end
```

- [ ] **Step 3: Add controller**

Create `Api::V1::AccountReconciliationStatementsController#show` that:

```ruby
authorize :account_reconciliation_statement
account = current_user.accounts.kept.find(params[:account_id])
statement = AccountReconciliation.new.build_statement(account: account, range: statement_range)
render json: { reconciliation_statement: statement_json(statement) }
```

Use `Date.iso8601` for `start_date` and `end_date`, defaulting to the current month when absent. Rescue `Date::Error` with `422` and `{ errors: [ "Start date and end date must be valid ISO 8601 dates" ] }`.

- [ ] **Step 4: Run focused test to verify GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb`

Expected: PASS.

### Task 3: Verification and Commit

**Files:**
- All touched files from Tasks 1-2.

- [ ] **Step 1: Verify route table**

Run: `mise exec -- bin/rails routes -g reconciliation_statement`

Expected: route maps to `api/v1/account_reconciliation_statements#show`.

- [ ] **Step 2: Run full test suite**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run focused RuboCop**

Run: `mise exec -- bin/rubocop app/controllers/api/v1/account_reconciliation_statements_controller.rb app/policies/account_reconciliation_statement_policy.rb config/routes.rb test/integration/api/v1/accounts_test.rb`

Expected: PASS with no offenses.

- [ ] **Step 4: Commit**

Run:

```bash
git add config/routes.rb app/controllers/api/v1/account_reconciliation_statements_controller.rb app/policies/account_reconciliation_statement_policy.rb test/integration/api/v1/accounts_test.rb docs/superpowers/plans/2026-05-04-account-reconciliation-statement-api-slice.md
git commit --no-gpg-sign -m "feat: add account reconciliation statement api"
```
