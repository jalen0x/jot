# User Custom Exchange Rates API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add modern JSON API endpoints for the token owner to list, show, create, update, and delete custom exchange rates.

**Architecture:** Model custom rates as standard `resources :user_custom_exchange_rates` under `api/v1`, scoped to the token owner through policy scope. Keep rate parsing and default-currency validation in `UserCustomExchangeRate`, expose a user-facing decimal `rate` string from `as_json`, and avoid exposing internal `rate_scaled` or `user_id`. Do not add ezBookkeeping legacy `.json` routes, camelCase params, or compatibility envelopes.

**Tech Stack:** Rails 8.1 controller params, HTTP token auth, Pundit, prefix IDs, Minitest integration tests.

---

### Task 1: API Contract Tests

**Files:**
- Create: `test/integration/api/v1/user_custom_exchange_rates_test.rb`

- [x] **Step 1: Add index and show tests**

Cover `GET /api/v1/user_custom_exchange_rates` listing only the token owner's kept rates ordered by `currency_code`, excluding discarded and other-user rates. Cover `GET /api/v1/user_custom_exchange_rates/:id` for an owned rate and assert the JSON shape contains `id`, `currency_code`, and decimal string `rate`, not `user_id` or `rate_scaled`.

- [x] **Step 2: Add create and update tests**

Cover `POST /api/v1/user_custom_exchange_rates` with string params `currency_code: "eur"`, `rate: "1.25"`; expect `201`, `rate_scaled == 125_000_000`, and JSON `rate == "1.25"`. Cover `PATCH /api/v1/user_custom_exchange_rates/:id` with `currency_code: "gbp"`, `rate: "0.8"`; expect `200`, persisted normalized currency and scaled rate.

- [x] **Step 3: Add validation and ownership tests**

Cover rejecting the user's default currency with `422` and an error mentioning default currency. Cover not showing/updating/deleting another user's rate with `404` and unchanged persistence.

- [x] **Step 4: Run focused test to verify RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/user_custom_exchange_rates_test.rb`

Expected: FAIL with missing route/helper or controller because the API resource does not exist yet.

### Task 2: Implementation

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/api/v1/user_custom_exchange_rates_controller.rb`
- Modify: `app/models/user_custom_exchange_rate.rb`
- Modify: `app/policies/user_custom_exchange_rate_policy.rb`

- [x] **Step 1: Add API routes**

Inside `namespace :api do namespace :v1 do`, add:

```ruby
resources :user_custom_exchange_rates, only: [ :index, :show, :create, :update, :destroy ]
```

- [x] **Step 2: Add JSON shape**

In `app/models/user_custom_exchange_rate.rb`, add:

```ruby
def as_json(_options = {})
  {
    id: to_param,
    currency_code: currency_code,
    rate: rate.to_s("F")
  }
end
```

- [x] **Step 3: Add show/update policy predicates**

In `app/policies/user_custom_exchange_rate_policy.rb`, add:

```ruby
def show? = user.present? && record.user_id == user.id
def update? = user.present? && record.user_id == user.id
```

- [x] **Step 4: Add API controller**

Create `app/controllers/api/v1/user_custom_exchange_rates_controller.rb` with standard resource actions: scoped ordered index, scoped show/update/destroy, create through `current_user.user_custom_exchange_rates.build`, `status: :created` for create, `status: :unprocessable_content` for validation failures, and `head :no_content` for destroy.

- [x] **Step 5: Run focused test to verify GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/user_custom_exchange_rates_test.rb`

Expected: PASS.

### Task 3: Verification and Commit

**Files:**
- All touched files from Tasks 1-2.

- [x] **Step 1: Run full test suite**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [x] **Step 2: Run focused RuboCop**

Run: `mise exec -- bin/rubocop config/routes.rb app/controllers/api/v1/user_custom_exchange_rates_controller.rb app/models/user_custom_exchange_rate.rb app/policies/user_custom_exchange_rate_policy.rb test/integration/api/v1/user_custom_exchange_rates_test.rb`

Expected: PASS with no offenses.

- [x] **Step 3: Commit**

Run:

```bash
git add config/routes.rb app/controllers/api/v1/user_custom_exchange_rates_controller.rb app/models/user_custom_exchange_rate.rb app/policies/user_custom_exchange_rate_policy.rb test/integration/api/v1/user_custom_exchange_rates_test.rb docs/superpowers/plans/2026-05-04-user-custom-exchange-rates-api-slice.md
git commit --no-gpg-sign -m "feat: add custom exchange rates api"
```
