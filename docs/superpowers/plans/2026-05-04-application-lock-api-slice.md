# Application Lock API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modern Rails JSON resource for managing the current API user's application-lock setting.

**Architecture:** The API uses singular `resource :application_lock, only: [:show, :create, :destroy]`. `show` reports whether the setting is enabled, `create` enables it with current password plus six-digit PIN confirmation, and `destroy` disables it with current password. This API intentionally does not expose HTML session-only `lock`/`unlock` custom actions and does not add ezBookkeeping legacy routes or response envelopes.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit, HTTP token auth through `ApiController`, existing `ApplicationLock` model.

---

## Files

- Modify: `app/models/application_lock.rb`
- Create: `app/controllers/api/v1/application_locks_controller.rb`
- Modify: `config/routes.rb`
- Create: `test/integration/api/v1/application_locks_test.rb`

## Resource Contract

- `GET /api/v1/application_lock`
  - Disabled: `{ "application_lock": { "enabled": false } }`
  - Enabled: `{ "application_lock": { "enabled": true, "created_at": "..." } }`
- `POST /api/v1/application_lock`
  - Params: `{ "application_lock": { "current_password": "...", "pin_code": "123456", "pin_code_confirmation": "123456" } }`
  - Success: `201 Created` with enabled JSON.
  - Wrong password, mismatched confirmation, invalid PIN, or already enabled: `422` with top-level `errors`.
- `DELETE /api/v1/application_lock`
  - Params: `{ "application_lock": { "current_password": "..." } }`
  - Success: `204 No Content`.
  - Wrong password or not enabled: `422` with top-level `errors`.

## Task 1: RED Tests

- [ ] **Step 1: Add API integration tests**

Create `test/integration/api/v1/application_locks_test.rb` covering disabled status, enabled status without internal digest fields, successful create, wrong password rejection, invalid PIN rejection, successful destroy, wrong password destroy rejection, and other-user scoping via decoy data.

- [ ] **Step 2: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/application_locks_test.rb
```

Expected: failure because the API route/controller does not exist.

## Task 2: Implementation

- [ ] **Step 1: Add safe JSON to `ApplicationLock`**

Add `as_json` returning only `{ enabled: true, created_at: created_at.iso8601(3) }`.

- [ ] **Step 2: Add API controller**

Create `app/controllers/api/v1/application_locks_controller.rb` with `show`, `create`, and `destroy`, using `authorize :application_lock` for current-user setting checks and existing `ApplicationLock.digest` for PIN storage.

- [ ] **Step 3: Add route**

Add `resource :application_lock, only: [ :show, :create, :destroy ]` inside the `api/v1` namespace.

- [ ] **Step 4: Verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/application_locks_test.rb
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
mise exec -- bin/rubocop app/models/application_lock.rb app/controllers/api/v1/application_locks_controller.rb config/routes.rb test/integration/api/v1/application_locks_test.rb
```

Expected: no offenses.

- [ ] **Step 3: Commit implementation**

```bash
git add docs/superpowers/plans/2026-05-04-application-lock-api-slice.md app/models/application_lock.rb app/controllers/api/v1/application_locks_controller.rb config/routes.rb test/integration/api/v1/application_locks_test.rb
git commit --no-gpg-sign -m "feat: add application lock api"
```

- [ ] **Step 4: Merge back to local main**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-gpg-sign --no-ff feature/application-lock-api-slice
mise exec -- bin/rails test
```

- [ ] **Step 5: Cleanup worktree**

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/application-lock-api-slice
git branch -d feature/application-lock-api-slice
```
