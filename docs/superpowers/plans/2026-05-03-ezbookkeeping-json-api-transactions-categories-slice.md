# ezBookkeeping JSON API Transactions And Categories Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add token-authenticated JSON read endpoints for transaction categories and transactions.

**Architecture:** Extend the existing `ApiController` boundary and `api/v1` namespace with read-only endpoints. Controllers stay thin, use Pundit scopes, and render explicit API-safe hashes through model `as_json` methods without adding a serializer dependency. This slice intentionally does not implement legacy ezBookkeeping `.json` paths, write endpoints, pagination, or full source API response compatibility.

**Tech Stack:** Rails 8.1, Devise/Pundit, ApiToken bearer authentication, Minitest integration tests, existing `TransactionCategory`, `Transaction`, and `LedgerQuery` domain objects.

---

## File Structure

- Modify `config/routes.rb`: add `api/v1` routes for `transaction_categories#index` and `transactions#index`.
- Create `app/controllers/api/v1/transaction_categories_controller.rb`: list current user's kept categories ordered for clients.
- Create `app/controllers/api/v1/transactions_controller.rb`: list current user's kept transactions through `LedgerQuery`, with a small `transaction_kind` filter.
- Modify `app/models/transaction_category.rb`: API-safe JSON fields, including prefixed parent id.
- Modify `app/models/transaction.rb`: API-safe JSON fields, including prefixed account/category/tag ids and no internal ownership columns.
- Create `test/integration/api/v1/transaction_categories_test.rb`: response shape, owner scoping, discarded filtering.
- Create `test/integration/api/v1/transactions_test.rb`: response shape, owner scoping, discarded filtering, ordering, and kind filtering.

---

### Task 1: Add `GET /api/v1/transaction_categories`

**Files:**
- Create: `test/integration/api/v1/transaction_categories_test.rb`
- Create: `app/controllers/api/v1/transaction_categories_controller.rb`
- Modify: `app/models/transaction_category.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing endpoint test**

Create `test/integration/api/v1/transaction_categories_test.rb` proving a valid bearer token returns `{ transaction_categories: [...] }`, includes only the token owner's kept categories, orders by `category_type`, `display_order`, `name`, includes prefixed `parent_category_id`, and does not expose `user_id`.

- [ ] **Step 2: Run test to verify RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/transaction_categories_test.rb`

Expected: FAIL with missing route/controller or missing JSON shape.

- [ ] **Step 3: Implement route, controller, and JSON shape**

Add `resources :transaction_categories, only: :index` under `api/v1`. Implement `Api::V1::TransactionCategoriesController#index` with `authorize TransactionCategory`, `policy_scope(TransactionCategory).kept.order(:category_type, :display_order, :name)`, and `render json: { transaction_categories: categories.map(&:as_json) }`. Add `TransactionCategory#as_json` with `id`, `name`, `category_type`, `parent_category_id`, `display_order`, `icon_key`, `color_hex`, `hidden`, and `comment`.

- [ ] **Step 4: Run category API test GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/transaction_categories_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit category API endpoint**

```bash
git add config/routes.rb app/controllers/api/v1/transaction_categories_controller.rb app/models/transaction_category.rb test/integration/api/v1/transaction_categories_test.rb
git commit --no-gpg-sign -m "feat: add transaction categories api"
```

---

### Task 2: Add `GET /api/v1/transactions`

**Files:**
- Create: `test/integration/api/v1/transactions_test.rb`
- Create: `app/controllers/api/v1/transactions_controller.rb`
- Modify: `app/models/transaction.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing endpoint tests**

Create `test/integration/api/v1/transactions_test.rb` proving a valid bearer token returns `{ transactions: [...] }`, includes only the token owner's kept transactions, orders newest first, includes prefixed account/category/tag ids, does not expose `user_id`, and supports `transaction_kind=income` as an HTTP string filter.

- [ ] **Step 2: Run test to verify RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb`

Expected: FAIL with missing route/controller or missing JSON shape.

- [ ] **Step 3: Implement route, controller, and JSON shape**

Add `resources :transactions, only: :index` under `api/v1`. Implement `Api::V1::TransactionsController#index` with `authorize Transaction`, `LedgerQuery.new.list_transactions(user: current_user, filters: filter_params)`, and `render json: { transactions: transactions.map(&:as_json) }`. Permit only `:transaction_kind` in API `filter_params` for this slice. Add `Transaction#as_json` with `id`, `transaction_kind`, `account_id`, `destination_account_id`, `transaction_category_id`, `transacted_at`, `timezone_utc_offset_minutes`, `source_amount_cents`, `destination_amount_cents`, `hide_amount`, `comment`, and `transaction_tag_ids`.

- [ ] **Step 4: Run transaction API test GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/transactions_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit transaction API endpoint**

```bash
git add config/routes.rb app/controllers/api/v1/transactions_controller.rb app/models/transaction.rb test/integration/api/v1/transactions_test.rb
git commit --no-gpg-sign -m "feat: add transactions api"
```

---

### Task 3: Verify JSON API transactions/categories slice

- [ ] **Step 1: Run focused API tests**

Run: `mise exec -- bin/rails test test/integration/api/v1/transaction_categories_test.rb test/integration/api/v1/transactions_test.rb test/integration/api/v1/accounts_test.rb test/integration/api/authentication_test.rb test/integration/api/content_negotiation_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run lint for touched files**

Run: `mise exec -- bin/rubocop app/controllers/api/v1/transaction_categories_controller.rb app/controllers/api/v1/transactions_controller.rb app/models/transaction_category.rb app/models/transaction.rb test/integration/api/v1/transaction_categories_test.rb test/integration/api/v1/transactions_test.rb config/routes.rb`

Expected: PASS.

- [ ] **Step 4: Check git status**

Run: `git status --short`

Expected: clean working tree.

---

## Self-Review

- Spec coverage: extends the Phase 8 JSON API seam with the next read-only resources after accounts, using token auth, content negotiation, top-level response keys, explicit response shapes, and current-user scoping.
- Scope control: does not implement write endpoints, legacy source paths, full filters, pagination, pictures, geo location, or MCP adapters; those remain separate slices.
- Placeholder scan: no TODO/TBD placeholders remain.
- Type consistency: route helpers, controller names, model methods, and tests consistently use `transaction_categories`, `transactions`, `TransactionCategory#as_json`, and `Transaction#as_json`.
