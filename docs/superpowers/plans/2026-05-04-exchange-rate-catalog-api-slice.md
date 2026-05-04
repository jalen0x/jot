# Exchange Rate Catalog API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modern Rails JSON resource that returns the current API user's effective exchange-rate catalog.

**Architecture:** `ExchangeRateCatalog` is a service object that builds a current-user catalog from `UserPreference` and kept `UserCustomExchangeRate` records. The API exposes it as singular `resource :exchange_rate_catalog, only: :show` and returns a top-level `exchange_rate_catalog` object. This slice does not add provider snapshots, external HTTP calls, old `.json` endpoints, camelCase params, or legacy response envelopes.

**Tech Stack:** Rails 8.1, Minitest integration/service tests, Pundit, HTTP token auth through `ApiController`.

---

## Files

- Create: `app/services/exchange_rate_catalog.rb`
- Create: `app/policies/exchange_rate_catalog_policy.rb`
- Create: `app/controllers/api/v1/exchange_rate_catalogs_controller.rb`
- Create: `test/services/exchange_rate_catalog_test.rb`
- Create: `test/integration/api/v1/exchange_rate_catalogs_test.rb`
- Modify: `config/routes.rb`

## Resource Contract

- Route: `GET /api/v1/exchange_rate_catalog`
- Response shape:

```json
{
  "exchange_rate_catalog": {
    "base_currency_code": "USD",
    "exchange_rates": [
      { "currency_code": "EUR", "rate": "1.25" },
      { "currency_code": "USD", "rate": "1" }
    ]
  }
}
```

- The base currency comes from `user.user_preference.default_currency_code`, falling back to `USD`.
- The base currency is always included with rate `1`.
- Kept custom exchange rates for the current user are included.
- Discarded rates and other users' rates are excluded.
- Rates are sorted by `currency_code` for stable clients.

## Task 1: RED Tests

- [ ] **Step 1: Add service tests**

Create `test/services/exchange_rate_catalog_test.rb` with tests for base currency fallback, custom-rate inclusion, discarded-rate exclusion, and other-user exclusion.

- [ ] **Step 2: Add API tests**

Create `test/integration/api/v1/exchange_rate_catalogs_test.rb` with a token-authenticated `GET /api/v1/exchange_rate_catalog` test that asserts top-level response shape, sorted rates, current-user scoping, and absence of internal fields.

- [ ] **Step 3: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/services/exchange_rate_catalog_test.rb test/integration/api/v1/exchange_rate_catalogs_test.rb
```

Expected: failure because `ExchangeRateCatalog` or the API route/controller does not exist.

## Task 2: Implementation

- [ ] **Step 1: Add `ExchangeRateCatalog` service**

Create `app/services/exchange_rate_catalog.rb` with `latest_rates(user:)`, plus small result value objects that implement `as_json`.

- [ ] **Step 2: Add Pundit policy**

Create `app/policies/exchange_rate_catalog_policy.rb` with `show? = user.present?`.

- [ ] **Step 3: Add API controller**

Create `app/controllers/api/v1/exchange_rate_catalogs_controller.rb` that authorizes `ExchangeRateCatalog`, calls the service, and renders `{ exchange_rate_catalog: catalog }`.

- [ ] **Step 4: Add route**

Add `resource :exchange_rate_catalog, only: :show` inside `api/v1` routes.

- [ ] **Step 5: Verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/services/exchange_rate_catalog_test.rb test/integration/api/v1/exchange_rate_catalogs_test.rb
```

Expected: all focused tests pass.

## Task 3: Verification And Merge

- [ ] **Step 1: Run full Rails tests**

```bash
mise exec -- bin/rails test
```

Expected: 0 failures, 0 errors.

- [ ] **Step 2: Run targeted RuboCop**

```bash
mise exec -- bin/rubocop app/services/exchange_rate_catalog.rb app/policies/exchange_rate_catalog_policy.rb app/controllers/api/v1/exchange_rate_catalogs_controller.rb config/routes.rb test/services/exchange_rate_catalog_test.rb test/integration/api/v1/exchange_rate_catalogs_test.rb
```

Expected: no offenses.

- [ ] **Step 3: Commit implementation**

```bash
git add docs/superpowers/plans/2026-05-04-exchange-rate-catalog-api-slice.md app/services/exchange_rate_catalog.rb app/policies/exchange_rate_catalog_policy.rb app/controllers/api/v1/exchange_rate_catalogs_controller.rb config/routes.rb test/services/exchange_rate_catalog_test.rb test/integration/api/v1/exchange_rate_catalogs_test.rb
git commit --no-gpg-sign -m "feat: add exchange rate catalog api"
```

- [ ] **Step 4: Merge back to local main**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-gpg-sign --no-ff feature/exchange-rate-catalog-api-slice
mise exec -- bin/rails test
```

- [ ] **Step 5: Cleanup worktree**

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/exchange-rate-catalog-api-slice
git branch -d feature/exchange-rate-catalog-api-slice
```
