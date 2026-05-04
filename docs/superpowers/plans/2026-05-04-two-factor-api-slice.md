# Two-Factor API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add modern Rails JSON resources for current-user two-factor setup, enable/disable status, and recovery-code regeneration.

**Architecture:** The API uses `resource :two_factor_setup`, `resource :two_factor_authentication`, and `resource :two_factor_recovery_codes`. Setup returns an ephemeral TOTP secret and provisioning URI after current-password verification; enable persists the submitted secret only after OTP verification; recovery-code generation reuses the existing service. This slice does not add legacy `/users/2fa/*.json` routes, camelCase params, QR-code data URLs, or token refresh semantics from the Go implementation.

**Tech Stack:** Rails 8.1, Minitest integration tests, ROTP, Pundit, HTTP token auth through `ApiController`, existing `TwoFactorAuthenticationEnabler` and `TwoFactorRecoveryCodeGenerator` services.

---

## Files

- Modify: `app/models/two_factor_authentication.rb`
- Create: `app/controllers/api/v1/two_factor_setups_controller.rb`
- Create: `app/controllers/api/v1/two_factor_authentications_controller.rb`
- Create: `app/controllers/api/v1/two_factor_recovery_codes_controller.rb`
- Modify: `config/routes.rb`
- Create: `test/integration/api/v1/two_factor_authentications_test.rb`

## Resource Contract

- `POST /api/v1/two_factor_setup`
  - Params: `{ "two_factor_setup": { "current_password": "..." } }`
  - Success: `201 Created` with `{ "two_factor_setup": { "otp_secret": "...", "provisioning_uri": "..." } }`.
  - Wrong password or already enabled: `422` with top-level `errors`.
- `GET /api/v1/two_factor_authentication`
  - Disabled: `{ "two_factor_authentication": { "enabled": false } }`
  - Enabled: `{ "two_factor_authentication": { "enabled": true, "enabled_at": "..." } }`
- `POST /api/v1/two_factor_authentication`
  - Params: `{ "two_factor_authentication": { "current_password": "...", "otp_secret": "...", "otp_code": "123456" } }`
  - Success: `201 Created` with safe 2FA status plus raw recovery codes under `two_factor_recovery_codes`.
  - Wrong password, invalid code, or already enabled: `422` with `errors`.
- `DELETE /api/v1/two_factor_authentication`
  - Params: `{ "two_factor_authentication": { "current_password": "..." } }`
  - Success: `204 No Content`.
- `POST /api/v1/two_factor_recovery_codes`
  - Params: `{ "two_factor_recovery_codes": { "current_password": "..." } }`
  - Success: `201 Created` with `{ "two_factor_recovery_codes": ["abcde-12345", ...] }`.

## Task 1: RED Tests

- [ ] **Step 1: Add API integration tests**

Create `test/integration/api/v1/two_factor_authentications_test.rb` covering disabled status, setup generation, enable success, invalid-code rejection, disable success, recovery-code regeneration, and no internal secret/digest fields in JSON.

- [ ] **Step 2: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/two_factor_authentications_test.rb
```

Expected: route/helper errors because the API resources do not exist.

## Task 2: Implementation

- [ ] **Step 1: Add safe JSON to `TwoFactorAuthentication`**

Add `as_json` returning only `{ enabled: true, enabled_at: enabled_at.iso8601(3) }`.

- [ ] **Step 2: Add API controllers**

Create setup, authentication, and recovery-code API controllers. Keep controllers thin and reuse existing services for enabling and recovery-code generation.

- [ ] **Step 3: Add routes**

Add the three singular resources inside `api/v1` routes.

- [ ] **Step 4: Verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/two_factor_authentications_test.rb
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
mise exec -- bin/rubocop app/models/two_factor_authentication.rb app/controllers/api/v1/two_factor_setups_controller.rb app/controllers/api/v1/two_factor_authentications_controller.rb app/controllers/api/v1/two_factor_recovery_codes_controller.rb config/routes.rb test/integration/api/v1/two_factor_authentications_test.rb
```

Expected: no offenses.

- [ ] **Step 3: Commit implementation**

```bash
git add docs/superpowers/plans/2026-05-04-two-factor-api-slice.md app/models/two_factor_authentication.rb app/controllers/api/v1/two_factor_setups_controller.rb app/controllers/api/v1/two_factor_authentications_controller.rb app/controllers/api/v1/two_factor_recovery_codes_controller.rb config/routes.rb test/integration/api/v1/two_factor_authentications_test.rb
git commit --no-gpg-sign -m "feat: add two-factor api"
```

- [ ] **Step 4: Merge back to local main**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-gpg-sign --no-ff feature/two-factor-api-slice
mise exec -- bin/rails test
```

- [ ] **Step 5: Cleanup worktree**

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/two-factor-api-slice
git branch -d feature/two-factor-api-slice
```
