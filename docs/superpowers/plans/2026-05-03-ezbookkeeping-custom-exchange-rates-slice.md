# ezBookkeeping Custom Exchange Rates Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Phase 4 `UserCustomExchangeRate` support so signed-in users can manage custom currency rates relative to their default currency.

**Architecture:** Store user custom rates in a soft-deletable `UserCustomExchangeRate` table with integer scaled values (`100_000_000` = 1.0). Keep decimal parsing in the model as a virtual `rate` attribute, keep update-or-create workflow in a small service object, and keep controllers scoped to `current_user`. When all ledger data is cleared, custom exchange rates are discarded too.

**Tech Stack:** Rails 8.1, PostgreSQL `structure.sql`, Devise, Pundit, Minitest, FactoryBot, discard gem, BigDecimal, Flowbite semantic Tailwind classes.

---

## File Structure

- Create `db/migrate/20260503140000_create_user_custom_exchange_rates.rb`: user-owned soft-deletable custom exchange rates.
- Create `app/models/user_custom_exchange_rate.rb`: normalization, scaled integer conversion, default-currency rejection.
- Modify `app/models/user.rb`: `has_many :user_custom_exchange_rates`.
- Create `app/services/user_custom_exchange_rate_saver.rb`: upsert-like save for one active rate per user/currency.
- Modify `app/services/ledger_clearance.rb`: discard custom exchange rates during `clear_all_data`.
- Create `app/policies/user_custom_exchange_rate_policy.rb`: scope records to current user.
- Create `app/controllers/user_custom_exchange_rates_controller.rb`: index/create/destroy.
- Create `app/views/user_custom_exchange_rates/index.html.erb`: list, add/update form, delete actions.
- Modify `config/routes.rb`: add `resources :user_custom_exchange_rates, only: [:index, :create, :destroy]`.
- Modify `app/views/layouts/application.html.erb`: add signed-in `Exchange Rates` nav link.
- Create `test/models/user_custom_exchange_rate_test.rb`: model validation and decimal conversion.
- Create `test/services/user_custom_exchange_rate_saver_test.rb`: create/update/scoping service behavior.
- Create `test/integration/user_custom_exchange_rates_test.rb`: auth, listing, create/update, invalid default currency, destroy.
- Modify `test/services/ledger_clearance_test.rb`: all-data clearing discards custom rates.

---

### Task 1: Add model and persistence

**Files:**
- Create: `db/migrate/20260503140000_create_user_custom_exchange_rates.rb`
- Create: `app/models/user_custom_exchange_rate.rb`
- Modify: `app/models/user.rb`
- Test: `test/models/user_custom_exchange_rate_test.rb`

- [ ] **Step 1: Write failing model tests**

Create `test/models/user_custom_exchange_rate_test.rb` with tests for currency normalization, `rate` decimal conversion to scaled integer, invalid rate rejection, and rejecting the user's default currency.

- [ ] **Step 2: Run model tests to verify RED**

Run: `mise exec -- bin/rails test test/models/user_custom_exchange_rate_test.rb`

Expected: FAIL with `uninitialized constant UserCustomExchangeRate`.

- [ ] **Step 3: Implement migration/model/user association**

Use `SCALE = 100_000_000`, `rate_scaled` as `bigint`, `discarded_at`, unique active index on `[user_id, currency_code] WHERE discarded_at IS NULL`, check constraints for three-letter currency and positive rate, and `has_many :user_custom_exchange_rates` on `User`.

- [ ] **Step 4: Migrate and verify model tests GREEN**

Run: `mise exec -- bin/rails db:migrate`

Run: `mise exec -- bin/rails test test/models/user_custom_exchange_rate_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit model slice**

```bash
git add db/migrate/20260503140000_create_user_custom_exchange_rates.rb db/structure.sql app/models/user.rb app/models/user_custom_exchange_rate.rb test/models/user_custom_exchange_rate_test.rb
git commit -m "feat: add custom exchange rates"
```

---

### Task 2: Add save workflow and data clearing integration

**Files:**
- Create: `app/services/user_custom_exchange_rate_saver.rb`
- Test: `test/services/user_custom_exchange_rate_saver_test.rb`
- Modify: `app/services/ledger_clearance.rb`
- Modify: `test/services/ledger_clearance_test.rb`

- [ ] **Step 1: Write failing service tests**

Create `test/services/user_custom_exchange_rate_saver_test.rb` to prove saving creates a rate, saving the same currency updates the existing active row rather than duplicating it, and another user's matching currency remains untouched.

Update `test/services/ledger_clearance_test.rb` so `clear_all_data` proves custom exchange rates for that user are discarded.

- [ ] **Step 2: Run service tests to verify RED**

Run: `mise exec -- bin/rails test test/services/user_custom_exchange_rate_saver_test.rb test/services/ledger_clearance_test.rb`

Expected: FAIL with missing `UserCustomExchangeRateSaver` or uncleared exchange rates.

- [ ] **Step 3: Implement saver and clearing hook**

`UserCustomExchangeRateSaver#save_rate(user:, attributes:)` should normalize currency, find-or-initialize the user's active rate, assign `rate`, and return a result object with `saved?` and `rate`.

`LedgerClearance#clear_all_data` should discard `user.user_custom_exchange_rates.kept` along with other ledger data.

- [ ] **Step 4: Run service tests to verify GREEN**

Run: `mise exec -- bin/rails test test/services/user_custom_exchange_rate_saver_test.rb test/services/ledger_clearance_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit service slice**

```bash
git add app/services/user_custom_exchange_rate_saver.rb app/services/ledger_clearance.rb test/services/user_custom_exchange_rate_saver_test.rb test/services/ledger_clearance_test.rb
git commit -m "feat: save custom exchange rates"
```

---

### Task 3: Add custom exchange rate UI

**Files:**
- Create: `test/integration/user_custom_exchange_rates_test.rb`
- Create: `app/policies/user_custom_exchange_rate_policy.rb`
- Create: `app/controllers/user_custom_exchange_rates_controller.rb`
- Create: `app/views/user_custom_exchange_rates/index.html.erb`
- Modify: `config/routes.rb`
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Write failing integration tests**

Create integration tests proving authentication is required, the index only lists the signed-in user's kept rates, create/update works from HTTP string params, the default currency is rejected, and destroy discards only the signed-in user's rate.

- [ ] **Step 2: Run integration tests to verify RED**

Run: `mise exec -- bin/rails test test/integration/user_custom_exchange_rates_test.rb`

Expected: FAIL with missing route helper such as `user_custom_exchange_rates_path`.

- [ ] **Step 3: Add policy, controller, route, nav, and view**

Implement `resources :user_custom_exchange_rates, only: [:index, :create, :destroy]`, Pundit scope by user, an index/create/destroy controller, and a Flowbite semantic index page with a form for currency/rate and delete buttons for existing rates.

- [ ] **Step 4: Run integration tests to verify GREEN**

Run: `mise exec -- bin/rails test test/integration/user_custom_exchange_rates_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit HTTP/UI slice**

```bash
git add app/controllers/user_custom_exchange_rates_controller.rb app/policies/user_custom_exchange_rate_policy.rb app/views/user_custom_exchange_rates/index.html.erb config/routes.rb app/views/layouts/application.html.erb test/integration/user_custom_exchange_rates_test.rb
git commit -m "feat: add custom exchange rate UI"
```

---

### Task 4: Verify custom exchange-rate slice

- [ ] **Step 1: Run focused tests**

Run: `mise exec -- bin/rails test test/models/user_custom_exchange_rate_test.rb test/services/user_custom_exchange_rate_saver_test.rb test/services/ledger_clearance_test.rb test/integration/user_custom_exchange_rates_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run lint for touched files**

Run: `mise exec -- bin/rubocop db/migrate/20260503140000_create_user_custom_exchange_rates.rb app/models/user.rb app/models/user_custom_exchange_rate.rb app/services/user_custom_exchange_rate_saver.rb app/services/ledger_clearance.rb app/controllers/user_custom_exchange_rates_controller.rb app/policies/user_custom_exchange_rate_policy.rb test/models/user_custom_exchange_rate_test.rb test/services/user_custom_exchange_rate_saver_test.rb test/services/ledger_clearance_test.rb test/integration/user_custom_exchange_rates_test.rb`

Run: `mise exec -- bundle exec erb_lint app/views/user_custom_exchange_rates/index.html.erb app/views/layouts/application.html.erb`

Expected: PASS.

- [ ] **Step 4: Check git status**

Run: `git status --short`

Expected: clean working tree.

---

## Self-Review

- Spec coverage: implements the Phase 4 `UserCustomExchangeRate` artifact with user-scoped custom rates, integer scaled precision, basic management UI, and data-clearing integration. Automatic provider rates and provider refresh jobs remain future Phase 4 slices.
- Placeholder scan: no TODO/TBD placeholders remain.
- Type consistency: the plan consistently uses `UserCustomExchangeRate`, `currency_code`, `rate_scaled`, `rate`, and `UserCustomExchangeRateSaver`.
