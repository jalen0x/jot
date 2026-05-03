# ezBookkeeping JSON API Accounts Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first Rails JSON API boundary: token-authenticated `GET /api/v1/accounts` returning the current user's kept accounts.

**Architecture:** Add `ApiController` as the shared JSON/API boundary with content negotiation and HTTP Bearer token authentication backed by `ApiToken`. Add a small `Api::V1::AccountsController#index` endpoint that uses Pundit scope and top-level JSON keys. Keep the response Rails-native and explicit; no serializer dependency.

**Tech Stack:** Rails 8.1, Devise/Pundit, ApiToken BCrypt digests, Minitest integration tests, route namespace `api/v1`.

---

## File Structure

- Create `app/controllers/api_controller.rb`: `require_json`, bearer token authentication, `current_user` for Pundit.
- Modify `app/models/api_token.rb`: class method `authenticate(raw_token)` and last-used helper if needed.
- Modify `app/models/account.rb`: API-safe JSON representation for exposed account fields.
- Create `app/controllers/api/v1/accounts_controller.rb`: `index` endpoint.
- Modify `config/routes.rb`: add `namespace :api; namespace :v1; resources :accounts, only: :index`.
- Create `test/integration/api/authentication_test.rb`: missing/wrong token returns 401.
- Create `test/integration/api/content_negotiation_test.rb`: non-JSON request returns 406.
- Create `test/integration/api/v1/accounts_test.rb`: scoped account response shape.

---

### Task 1: Add API authentication and content negotiation

**Files:**
- Create: `test/integration/api/authentication_test.rb`
- Create: `test/integration/api/content_negotiation_test.rb`
- Create: `app/controllers/api_controller.rb`
- Modify: `app/models/api_token.rb`

- [ ] **Step 1: Write failing API boundary tests**

Create tests proving `GET /api/v1/accounts` with JSON Accept but no token returns 401, wrong token returns 401, and a non-JSON request with a valid token returns 406.

- [ ] **Step 2: Run tests to verify RED**

Run: `mise exec -- bin/rails test test/integration/api/authentication_test.rb test/integration/api/content_negotiation_test.rb`

Expected: FAIL with missing route/controller.

- [ ] **Step 3: Implement `ApiController` and token authentication**

`ApiController` should reject non-JSON requests before authentication, authenticate `Authorization: Bearer <token>` against `ApiToken.authenticate`, set `@current_api_user`, update `last_used_at`, and expose `current_user` so Pundit scopes work.

- [ ] **Step 4: Run boundary tests GREEN after the endpoint route exists in Task 2**

These tests may continue failing for missing route until Task 2 adds the route. Do not change their assertions.

---

### Task 2: Add `GET /api/v1/accounts`

**Files:**
- Create: `test/integration/api/v1/accounts_test.rb`
- Create: `app/controllers/api/v1/accounts_controller.rb`
- Modify: `app/models/account.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing account endpoint test**

Create a test proving a valid token returns `{ accounts: [...] }`, includes only the token owner's kept accounts, and does not expose internal `user_id`.

- [ ] **Step 2: Run account endpoint test RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb`

Expected: FAIL with missing route/controller.

- [ ] **Step 3: Implement route/controller/JSON shape**

Add the `api/v1` route and controller. Render `accounts: accounts.map(&:as_json)` with account fields `id`, `name`, `account_category`, `account_structure`, `currency_code`, `balance_cents`, `parent_account_id`, and `hidden`.

- [ ] **Step 4: Run API tests GREEN**

Run: `mise exec -- bin/rails test test/integration/api/authentication_test.rb test/integration/api/content_negotiation_test.rb test/integration/api/v1/accounts_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit API slice**

```bash
git add app/controllers/api_controller.rb app/controllers/api/v1/accounts_controller.rb app/models/api_token.rb app/models/account.rb config/routes.rb test/integration/api/authentication_test.rb test/integration/api/content_negotiation_test.rb test/integration/api/v1/accounts_test.rb
git commit -m "feat: add token-authenticated accounts api"
```

---

### Task 3: Verify JSON API accounts slice

- [ ] **Step 1: Run focused API tests**

Run: `mise exec -- bin/rails test test/integration/api/authentication_test.rb test/integration/api/content_negotiation_test.rb test/integration/api/v1/accounts_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run lint for touched files**

Run: `mise exec -- bin/rubocop app/controllers/api_controller.rb app/controllers/api/v1/accounts_controller.rb app/models/api_token.rb app/models/account.rb test/integration/api/authentication_test.rb test/integration/api/content_negotiation_test.rb test/integration/api/v1/accounts_test.rb`

Expected: PASS.

- [ ] **Step 4: Check git status**

Run: `git status --short`

Expected: clean working tree.

---

## Self-Review

- Spec coverage: implements the first Phase 8 JSON API seam and uses the Phase 5 `ApiToken` boundary. It covers authentication, content negotiation, top-level response keys, and user scoping. It does not implement legacy ezBookkeeping `/v1/accounts/list.json` compatibility, write endpoints, pagination, MCP, or broader API resources.
- Placeholder scan: no TODO/TBD placeholders remain.
- Type consistency: the plan consistently uses `ApiController`, `Api::V1::AccountsController`, `ApiToken.authenticate`, and `api_v1_accounts_path`.
