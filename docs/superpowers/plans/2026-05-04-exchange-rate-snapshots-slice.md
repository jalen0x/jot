# Exchange Rate Snapshots Foundation Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add durable automatic exchange-rate snapshot storage and merge provider rates into the existing current-user exchange-rate catalog.

**Architecture:** `ExchangeRateSnapshot` stores provider-observed rates as relational rows keyed by data source, base currency, target currency, and observation time. `ExchangeRateCatalog#latest_rates` reads the latest snapshot per target currency for the user's default base currency, includes the base currency at `1`, and lets kept `UserCustomExchangeRate` rows override provider rates. This slice intentionally does not add external HTTP provider adapters, jobs, UI, legacy `/exchange_rates/latest.json`, or cross-base currency conversion.

**Tech Stack:** Rails 8.1, PostgreSQL constraints, Minitest model/service/API tests, existing `ExchangeRateCatalog` API.

---

## Files

- Create: `db/migrate/20260504103000_create_exchange_rate_snapshots.rb`
- Create: `app/models/exchange_rate_snapshot.rb`
- Modify: `app/services/exchange_rate_catalog.rb`
- Create: `test/models/exchange_rate_snapshot_test.rb`
- Modify: `test/services/exchange_rate_catalog_test.rb`
- Modify: `test/integration/api/v1/exchange_rate_catalogs_test.rb`

## Data Contract

- `ExchangeRateSnapshot#data_source`: provider name/key, required.
- `ExchangeRateSnapshot#base_currency_code`: ISO currency code for the rate base, required and normalized uppercase.
- `ExchangeRateSnapshot#currency_code`: ISO target currency code, required and normalized uppercase.
- `ExchangeRateSnapshot#rate_scaled`: positive integer using `UserCustomExchangeRate::SCALE`.
- `ExchangeRateSnapshot#observed_at`: provider observation time, required.
- `ExchangeRateSnapshot#reference_url`: optional provider reference URL.
- Unique key: `data_source + base_currency_code + currency_code + observed_at`.

## Catalog Merge Rules

- The user's default currency remains the catalog base currency, falling back to `USD`.
- Base currency is always included with rate `1`.
- Provider snapshots are included only when `base_currency_code` matches the user's base currency.
- For each target currency, only the latest snapshot by `observed_at` is used.
- Kept user custom rates override provider rates with the same target currency.
- Rates remain sorted by `currency_code`.

## Task 1: RED Tests

- [ ] **Step 1: Add model tests**

Create `test/models/exchange_rate_snapshot_test.rb` covering normalization, rate assignment/scaling, duplicate validation, and database positive-rate constraint.

- [ ] **Step 2: Extend catalog service tests**

Update `test/services/exchange_rate_catalog_test.rb` to assert provider rates are included, latest snapshot wins, mismatched base currency is ignored, and custom rates override provider rates.

- [ ] **Step 3: Extend API test**

Update `test/integration/api/v1/exchange_rate_catalogs_test.rb` to prove provider rates flow through the JSON API without internal fields.

- [ ] **Step 4: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/models/exchange_rate_snapshot_test.rb test/services/exchange_rate_catalog_test.rb test/integration/api/v1/exchange_rate_catalogs_test.rb
```

Expected: failure because `ExchangeRateSnapshot` table/model do not exist and catalog does not read provider snapshots.

## Task 2: Implementation

- [ ] **Step 1: Add migration and migrate**

Create the migration with comments, check constraints, and indexes, then run `mise exec -- bin/rails db:migrate`.

- [ ] **Step 2: Add model**

Create `ExchangeRateSnapshot` with normalization, validations, `rate` getter/setter, and safe `as_json` if needed later.

- [ ] **Step 3: Wire associations**

Add `has_many :exchange_rate_snapshots, dependent: :restrict_with_error` to `User` only if snapshots become user-owned. This slice keeps snapshots global, so do not add a `User` association.

- [ ] **Step 4: Update catalog service**

Merge latest provider snapshots for the user's base currency with custom rates, using custom rates as the final override.

- [ ] **Step 5: Verify GREEN**

Run the focused tests from Task 1.

## Task 3: Verification And Merge

- [ ] **Step 1: Run full Rails tests**

```bash
mise exec -- bin/rails test
```

Expected: 0 failures, 0 errors.

- [ ] **Step 2: Run targeted RuboCop**

```bash
mise exec -- bin/rubocop db/migrate/20260504103000_create_exchange_rate_snapshots.rb app/models/exchange_rate_snapshot.rb app/services/exchange_rate_catalog.rb test/models/exchange_rate_snapshot_test.rb test/services/exchange_rate_catalog_test.rb test/integration/api/v1/exchange_rate_catalogs_test.rb
```

Expected: no offenses.

- [ ] **Step 3: Commit implementation**

```bash
git add docs/superpowers/plans/2026-05-04-exchange-rate-snapshots-slice.md db/migrate/20260504103000_create_exchange_rate_snapshots.rb db/structure.sql app/models/exchange_rate_snapshot.rb app/services/exchange_rate_catalog.rb test/models/exchange_rate_snapshot_test.rb test/services/exchange_rate_catalog_test.rb test/integration/api/v1/exchange_rate_catalogs_test.rb
git commit --no-gpg-sign -m "feat: add exchange rate snapshots"
```

- [ ] **Step 4: Merge back to local main**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-gpg-sign --no-ff feature/exchange-rate-snapshots-slice
mise exec -- bin/rails test
```

- [ ] **Step 5: Cleanup worktree**

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/exchange-rate-snapshots-slice
git branch -d feature/exchange-rate-snapshots-slice
```
