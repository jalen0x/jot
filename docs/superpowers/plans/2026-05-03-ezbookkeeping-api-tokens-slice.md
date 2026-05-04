# ezBookkeeping API Tokens Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Phase 5 API token foundation so signed-in users can issue and revoke API tokens without storing raw token values.

**Architecture:** Use a Rails-native `ApiToken` model rather than copying Go JWT token internals. Store only a BCrypt digest, show the raw token exactly once after issuance, require the user's current password to issue a token, and soft-delete revoked tokens. The Rails-native JSON API authenticates with `ApiToken.authenticate(raw_token)`.

**Tech Stack:** Rails 8.1, PostgreSQL `structure.sql`, Devise, Pundit, Minitest, FactoryBot, discard gem, BCrypt, SecureRandom, Flowbite semantic Tailwind classes.

---

## File Structure

- Create `db/migrate/20260503150000_create_api_tokens.rb`: user-owned soft-deletable token digests.
- Create `app/models/api_token.rb`: digest matching, expiry checks, validations.
- Modify `app/models/user.rb`: `has_many :api_tokens`.
- Create `app/services/api_token_issuer.rb`: generate raw token, store digest, return raw token once.
- Create `app/policies/api_token_policy.rb`: scope tokens to current user.
- Create `app/controllers/api_tokens_controller.rb`: index/create/destroy.
- Create `app/views/api_tokens/index.html.erb`: issue form, one-time token display, active token list, revoke buttons.
- Modify `config/routes.rb`: add `resources :api_tokens, only: [:index, :create, :destroy]`.
- Modify `app/views/layouts/application.html.erb`: add signed-in `API Tokens` nav link.
- Create `test/models/api_token_test.rb`: digest matching, expiry, validations.
- Create `test/services/api_token_issuer_test.rb`: raw token issuance, digest storage, expiry handling.
- Create `test/integration/api_tokens_test.rb`: authentication, password check, one-time display, user scoping, revoke.

---

### Task 1: Add ApiToken model and table

**Files:**
- Create: `db/migrate/20260503150000_create_api_tokens.rb`
- Create: `app/models/api_token.rb`
- Modify: `app/models/user.rb`
- Test: `test/models/api_token_test.rb`

- [ ] **Step 1: Write failing model tests**

Create `test/models/api_token_test.rb` to prove raw tokens match digests, wrong tokens do not match, expired tokens are inactive, and blank names are invalid.

- [ ] **Step 2: Run model tests to verify RED**

Run: `mise exec -- bin/rails test test/models/api_token_test.rb`

Expected: FAIL with `uninitialized constant ApiToken`.

- [ ] **Step 3: Implement migration/model/user association**

Use columns `user_id`, `name`, `token_digest`, `last_used_at`, `expires_at`, `discarded_at`, timestamps. Add `has_prefix_id :tok`, `include Discard::Model`, `active` scope for kept and unexpired records, and `matches_token?` using BCrypt.

- [ ] **Step 4: Migrate and verify model tests GREEN**

Run: `mise exec -- bin/rails db:migrate`

Run: `mise exec -- bin/rails test test/models/api_token_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit model slice**

```bash
git add db/migrate/20260503150000_create_api_tokens.rb db/structure.sql app/models/user.rb app/models/api_token.rb test/models/api_token_test.rb
git commit -m "feat: add api tokens"
```

---

### Task 2: Add token issuance workflow

**Files:**
- Create: `app/services/api_token_issuer.rb`
- Test: `test/services/api_token_issuer_test.rb`

- [ ] **Step 1: Write failing service tests**

Create `test/services/api_token_issuer_test.rb` to prove issuing returns a raw token once, stores only a digest, records the name, and supports optional expiry days.

- [ ] **Step 2: Run service tests to verify RED**

Run: `mise exec -- bin/rails test test/services/api_token_issuer_test.rb`

Expected: FAIL with `uninitialized constant ApiTokenIssuer`.

- [ ] **Step 3: Implement issuer**

`ApiTokenIssuer#issue(user:, attributes:)` should generate `SecureRandom.urlsafe_base64(32)`, store a BCrypt digest, parse positive integer `expires_in_days`, and return a result object with `issued?`, `api_token`, and `raw_token`.

- [ ] **Step 4: Run service tests to verify GREEN**

Run: `mise exec -- bin/rails test test/services/api_token_issuer_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit service slice**

```bash
git add app/services/api_token_issuer.rb test/services/api_token_issuer_test.rb
git commit -m "feat: issue api tokens"
```

---

### Task 3: Add API token management UI

**Files:**
- Create: `test/integration/api_tokens_test.rb`
- Create: `app/policies/api_token_policy.rb`
- Create: `app/controllers/api_tokens_controller.rb`
- Create: `app/views/api_tokens/index.html.erb`
- Modify: `config/routes.rb`
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Write failing integration tests**

Create integration tests proving authentication is required, wrong password does not issue a token, correct password issues and displays the raw token exactly in that response, index lists only current user's active tokens, and destroy revokes only current user's token.

- [ ] **Step 2: Run integration tests to verify RED**

Run: `mise exec -- bin/rails test test/integration/api_tokens_test.rb`

Expected: FAIL with missing route helper such as `api_tokens_path`.

- [ ] **Step 3: Add policy, controller, route, nav, and view**

Implement `resources :api_tokens, only: [:index, :create, :destroy]`, Pundit scope by user, password confirmation in `create`, and a Flowbite semantic index page with a one-time raw token panel.

- [ ] **Step 4: Run integration tests to verify GREEN**

Run: `mise exec -- bin/rails test test/integration/api_tokens_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit HTTP/UI slice**

```bash
git add app/controllers/api_tokens_controller.rb app/policies/api_token_policy.rb app/views/api_tokens/index.html.erb config/routes.rb app/views/layouts/application.html.erb test/integration/api_tokens_test.rb
git commit -m "feat: add api token UI"
```

---

### Task 4: Verify API token slice

- [ ] **Step 1: Run focused tests**

Run: `mise exec -- bin/rails test test/models/api_token_test.rb test/services/api_token_issuer_test.rb test/integration/api_tokens_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run lint for touched files**

Run: `mise exec -- bin/rubocop db/migrate/20260503150000_create_api_tokens.rb app/models/user.rb app/models/api_token.rb app/services/api_token_issuer.rb app/controllers/api_tokens_controller.rb app/policies/api_token_policy.rb test/models/api_token_test.rb test/services/api_token_issuer_test.rb test/integration/api_tokens_test.rb`

Run: `mise exec -- bundle exec erb_lint app/views/api_tokens/index.html.erb app/views/layouts/application.html.erb`

Expected: PASS.

- [ ] **Step 4: Check git status**

Run: `git status --short`

Expected: clean working tree.

---

## Self-Review

- Spec coverage: implements the Phase 5 API token foundation used by the Rails-native JSON API. It does not yet add JSON API authentication middleware, session listing, 2FA, OIDC, or app lock.
- Placeholder scan: no TODO/TBD placeholders remain.
- Type consistency: the plan consistently uses `ApiToken`, `ApiTokenIssuer`, `token_digest`, `raw_token`, and `api_tokens_path`.
