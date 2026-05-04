# API Tokens API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add modern Rails JSON resources for current-user API token listing, issuance, and revocation.

**Architecture:** The API reuses existing `ApiToken`, `ApiTokenIssuer`, and Pundit policy. `GET /api/v1/api_tokens` lists active token metadata, `POST /api/v1/api_tokens` issues a new token after current-password verification, and `DELETE /api/v1/api_tokens/:id` revokes a kept token. Raw token material is returned only on creation and token digests are never serialized.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit, HTTP token auth through `ApiController`, BCrypt-backed token digests.

---

## Files

- Modify: `app/models/api_token.rb`
- Create: `app/controllers/api/v1/api_tokens_controller.rb`
- Modify: `config/routes.rb`
- Create: `test/integration/api/v1/api_tokens_test.rb`

## Resource Contract

- `GET /api/v1/api_tokens`
  - Success: `{ "api_tokens": [{ "id": "tok_...", "name": "CLI", "active": true, ... }] }`
  - Lists only current user's active kept tokens.
  - Excludes `token_digest` and raw token values.
- `POST /api/v1/api_tokens`
  - Params: `{ "api_token": { "name": "CLI", "expires_in_days": "30", "current_password": "..." } }`
  - Success: `201 Created` with `{ "api_token": { ... }, "raw_token": "..." }`.
  - Wrong password or invalid token attributes: `422` with top-level `errors`.
- `DELETE /api/v1/api_tokens/:id`
  - Success: `204 No Content`.
  - Other users' tokens are not found.

## Task 1: RED Tests

- [ ] **Step 1: Add API integration tests**

Create `test/integration/api/v1/api_tokens_test.rb` covering active-token listing, raw-token one-time creation, wrong-password rejection, current-user revocation, and other-user scoping.

- [ ] **Step 2: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/api_tokens_test.rb
```

Expected: route/helper errors because the API resource does not exist.

## Task 2: Implementation

- [ ] **Step 1: Add safe JSON to `ApiToken`**

Add `as_json` returning token metadata only: id, name, active, expires_at, last_used_at, created_at.

- [ ] **Step 2: Add API controller**

Create `app/controllers/api/v1/api_tokens_controller.rb` with `index`, `create`, and `destroy`.

- [ ] **Step 3: Add route**

Add `resources :api_tokens, only: [ :index, :create, :destroy ]` inside `api/v1` routes.

- [ ] **Step 4: Verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/api_tokens_test.rb
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
mise exec -- bin/rubocop app/models/api_token.rb app/controllers/api/v1/api_tokens_controller.rb config/routes.rb test/integration/api/v1/api_tokens_test.rb
```

Expected: no offenses.

- [ ] **Step 3: Commit implementation**

```bash
git add docs/superpowers/plans/2026-05-04-api-tokens-api-slice.md app/models/api_token.rb app/controllers/api/v1/api_tokens_controller.rb config/routes.rb test/integration/api/v1/api_tokens_test.rb
git commit --no-gpg-sign -m "feat: add api token management api"
```

- [ ] **Step 4: Merge back to local main**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-gpg-sign --no-ff feature/api-tokens-api-slice
mise exec -- bin/rails test
```

- [ ] **Step 5: Cleanup worktree**

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/api-tokens-api-slice
git branch -d feature/api-tokens-api-slice
```
