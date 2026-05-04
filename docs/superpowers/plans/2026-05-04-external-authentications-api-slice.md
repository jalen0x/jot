# External Authentications API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add modern Rails JSON resources for listing and unlinking the current user's external authentication link.

**Architecture:** The current Rails app has GitHub OmniAuth as the only external provider and stores the link on `users.provider` / `users.uid`. This slice wraps that existing state in a small non-DB `ExternalAuthentication` resource for API JSON. `DELETE` requires the current password before clearing `provider` and `uid`. This slice does not add OIDC providers, a new external-auth table, OAuth callback changes, or legacy ezBookkeeping `/users/external_auth/*.json` compatibility.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit, HTTP token auth through `ApiController`, existing Devise user password verification.

---

## Files

- Create: `app/models/external_authentication.rb`
- Create: `app/policies/external_authentication_policy.rb`
- Create: `app/controllers/api/v1/external_authentications_controller.rb`
- Modify: `config/routes.rb`
- Create: `test/integration/api/v1/external_authentications_test.rb`

## Resource Contract

- `GET /api/v1/external_authentications`
  - Success: `{ "external_authentications": [{ "id": "github", "provider": "github" }] }`.
  - Empty list when the current user has no external auth link.
  - Does not expose `uid`, `user_id`, or internal provider metadata.
- `DELETE /api/v1/external_authentications/:id`
  - Params: `{ "external_authentication": { "current_password": "..." } }`
  - Success: `204 No Content` and clears the current user's `provider` / `uid`.
  - Wrong password: `422` with top-level `errors`.
  - Unknown or unlinked provider: `404`.

## Task 1: RED Tests

- [ ] **Step 1: Add API integration tests**

Create `test/integration/api/v1/external_authentications_test.rb` covering list, empty list with decoy external auth on another user, successful unlink, wrong-password rejection, and unknown provider not found.

- [ ] **Step 2: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/external_authentications_test.rb
```

Expected: route/helper errors because the API resource does not exist.

## Task 2: Implementation

- [ ] **Step 1: Add value object**

Create `ExternalAuthentication` with `for_user(user)`, `find_for_user!(user, id)`, `to_param`, and safe `as_json`.

- [ ] **Step 2: Add Pundit policy**

Create `ExternalAuthenticationPolicy` allowing `index?` and `destroy?` for authenticated users.

- [ ] **Step 3: Add API controller and route**

Create `Api::V1::ExternalAuthenticationsController` with `index` and `destroy`; add `resources :external_authentications, only: [ :index, :destroy ]` inside `api/v1` routes.

- [ ] **Step 4: Verify GREEN**

Run the focused test from Task 1.

## Task 3: Verification And Merge

- [ ] **Step 1: Run full Rails tests**

```bash
mise exec -- bin/rails test
```

Expected: 0 failures, 0 errors.

- [ ] **Step 2: Run targeted RuboCop**

```bash
mise exec -- bin/rubocop app/models/external_authentication.rb app/policies/external_authentication_policy.rb app/controllers/api/v1/external_authentications_controller.rb config/routes.rb test/integration/api/v1/external_authentications_test.rb
```

Expected: no offenses.

- [ ] **Step 3: Commit implementation**

```bash
git add docs/superpowers/plans/2026-05-04-external-authentications-api-slice.md app/models/external_authentication.rb app/policies/external_authentication_policy.rb app/controllers/api/v1/external_authentications_controller.rb config/routes.rb test/integration/api/v1/external_authentications_test.rb
git commit --no-gpg-sign -m "feat: add external authentications api"
```

- [ ] **Step 4: Merge back to local main**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-gpg-sign --no-ff feature/external-authentications-api-slice
mise exec -- bin/rails test
```

- [ ] **Step 5: Cleanup worktree**

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/external-authentications-api-slice
git branch -d feature/external-authentications-api-slice
```
