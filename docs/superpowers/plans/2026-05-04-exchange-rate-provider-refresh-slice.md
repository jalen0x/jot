# Exchange Rate Provider Refresh Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first automatic exchange-rate provider adapter and a background-job refresh seam that persists provider snapshots.

**Architecture:** `ExchangeRateProviders::BankOfCanada` fetches and parses the Bank of Canada daily FX JSON feed into an inert `RateSet`. `ExchangeRateUpdater#refresh_rates(provider_key:)` performs the external provider fetch before opening the database transaction, then upserts `ExchangeRateSnapshot` rows. `ExchangeRateRefreshJob` is the async boundary and retries transient provider fetch failures. This slice does not add controller actions, UI, recurring production schedule, API keys, or legacy `/exchange_rates/latest.json` compatibility.

**Tech Stack:** Rails 8.1, Net::HTTP, JSON, WebMock tests, Minitest service/job tests, Solid Queue via Active Job.

---

## Files

- Create: `app/services/exchange_rate_providers.rb`
- Create: `app/services/exchange_rate_providers/bank_of_canada.rb`
- Create: `app/services/exchange_rate_updater.rb`
- Create: `app/jobs/exchange_rate_refresh_job.rb`
- Create: `test/services/exchange_rate_updater_test.rb`
- Create: `test/jobs/exchange_rate_refresh_job_test.rb`

## Provider Contract

- Provider registry key: `bank_of_canada`.
- Provider output: `ExchangeRateProviders::RateSet` with `data_source`, `reference_url`, `base_currency_code`, `observed_at`, and `rates`.
- Each rate has `currency_code` and decimal `rate`.
- Bank of Canada base currency is `CAD`.
- The adapter converts source `FXUSDCAD = 1.25` into catalog snapshot rate `0.8` because the stored snapshot is target currency per one base currency.

## Task 1: RED Tests

- [ ] **Step 1: Add updater tests**

Create `test/services/exchange_rate_updater_test.rb` using WebMock to stub the Bank of Canada response. Assert snapshots are persisted, duplicate refreshes update existing rows instead of duplicating, unsupported provider keys raise, and failed HTTP responses raise a provider fetch error without writing snapshots.

- [ ] **Step 2: Add job test**

Create `test/jobs/exchange_rate_refresh_job_test.rb` proving `ExchangeRateRefreshJob.perform_now("bank_of_canada")` persists snapshots through the updater.

- [ ] **Step 3: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/services/exchange_rate_updater_test.rb test/jobs/exchange_rate_refresh_job_test.rb
```

Expected: constant errors because provider/updater/job classes do not exist.

## Task 2: Implementation

- [ ] **Step 1: Add provider registry and value objects**

Create `ExchangeRateProviders.fetch(provider_key)`, `FetchError`, `UnsupportedProviderError`, `RateSet`, and `Rate`.

- [ ] **Step 2: Add Bank of Canada provider**

Use `Net::HTTP.get_response` and parse the JSON response. Reject failed HTTP responses and malformed payloads with `ExchangeRateProviders::FetchError`.

- [ ] **Step 3: Add updater service**

Fetch the provider outside the transaction, then persist snapshots inside a transaction with `find_or_initialize_by` on provider/base/currency/observed_at.

- [ ] **Step 4: Add refresh job**

Create `ExchangeRateRefreshJob` with transient retry behavior and a single `provider_key` argument.

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
mise exec -- bin/rubocop app/services/exchange_rate_providers.rb app/services/exchange_rate_providers/bank_of_canada.rb app/services/exchange_rate_updater.rb app/jobs/exchange_rate_refresh_job.rb test/services/exchange_rate_updater_test.rb test/jobs/exchange_rate_refresh_job_test.rb
```

Expected: no offenses.

- [ ] **Step 3: Commit implementation**

```bash
git add docs/superpowers/plans/2026-05-04-exchange-rate-provider-refresh-slice.md app/services/exchange_rate_providers.rb app/services/exchange_rate_providers/bank_of_canada.rb app/services/exchange_rate_updater.rb app/jobs/exchange_rate_refresh_job.rb test/services/exchange_rate_updater_test.rb test/jobs/exchange_rate_refresh_job_test.rb
git commit --no-gpg-sign -m "feat: add exchange rate provider refresh"
```

- [ ] **Step 4: Merge back to local main**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-gpg-sign --no-ff feature/exchange-rate-provider-refresh-slice
mise exec -- bin/rails test
```

- [ ] **Step 5: Cleanup worktree**

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/exchange-rate-provider-refresh-slice
git branch -d feature/exchange-rate-provider-refresh-slice
```
