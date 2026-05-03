# ezBookkeeping Application Lock Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Rails-native application lock that lets a signed-in user protect the app with a six-digit PIN after Devise authentication.

**Architecture:** Application lock is a current-user security resource, separate from Devise login and 2FA. A persisted `ApplicationLock` stores only a BCrypt PIN digest; the current browser session stores whether this signed-in user has unlocked the app. `ApplicationController` redirects locked sessions to an unlock page while leaving Devise, API-token requests, and the unlock action usable.

**Tech Stack:** Rails 8.1, Devise, Pundit, BCrypt, PostgreSQL migration + `db/structure.sql`, Minitest integration/model tests, Flowbite semantic classes.

---

## File Structure

- Create `db/migrate/20260503180000_create_application_locks.rb`: user-owned lock table with unique user id and PIN digest.
- Modify `db/structure.sql`: schema dump after migration.
- Create `app/models/application_lock.rb`: BCrypt digest creation, PIN normalization, and PIN match checks.
- Modify `app/models/user.rb`: `has_one :application_lock` and `application_lock_enabled?`.
- Create `app/policies/application_lock_policy.rb`: current-user access rules.
- Modify `app/controllers/application_controller.rb`: enforce app unlock for signed-in locked users, with session helper methods.
- Create `app/controllers/application_locks_controller.rb`: show settings, enable, disable, lock, and unlock actions.
- Modify `config/routes.rb`: singular `application_lock` resource with `lock` and `unlock` member actions.
- Modify `app/views/layouts/application.html.erb`: add App Lock navigation link for signed-in users.
- Create `app/views/application_locks/show.html.erb`: lock settings and enable/disable forms.
- Create `app/views/application_locks/unlock.html.erb`: PIN unlock page.
- Create `test/models/application_lock_test.rb`: digest-only storage and PIN matching.
- Create `test/integration/application_locks_test.rb`: enable/disable/lock/unlock and route gating.

---

### Task 1: Add `ApplicationLock` persistence and PIN matching

**Files:**
- Create: `db/migrate/20260503180000_create_application_locks.rb`
- Modify: `db/structure.sql`
- Create: `app/models/application_lock.rb`
- Modify: `app/models/user.rb`
- Create: `test/models/application_lock_test.rb`

- [ ] **Step 1: Write failing model tests**

Create `test/models/application_lock_test.rb` proving `ApplicationLock.digest("123456")` stores a BCrypt hash rather than the raw PIN, `matches_pin?("123456")` succeeds, `matches_pin?("000000")` fails, and a user cannot have two application locks.

- [ ] **Step 2: Run model test RED**

Run: `mise exec -- bin/rails test test/models/application_lock_test.rb`

Expected: FAIL with missing model/table.

- [ ] **Step 3: Add migration, model, and user association**

Create table `application_locks` with `user_id`, `pin_digest`, and timestamps. Add a unique index on `user_id`. Add `ApplicationLock.digest(pin)` using BCrypt with test-friendly cost, `ApplicationLock.normalize_pin(pin)`, `matches_pin?(pin)`, validations for `pin_digest` and unique `user_id`, `User#application_lock_enabled?`, and `has_one :application_lock, dependent: :destroy`.

- [ ] **Step 4: Run migration and model test GREEN**

Run: `mise exec -- bin/rails db:migrate && mise exec -- bin/rails test test/models/application_lock_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit model slice**

```bash
git add db/migrate/20260503180000_create_application_locks.rb db/structure.sql app/models/application_lock.rb app/models/user.rb test/models/application_lock_test.rb
git commit --no-gpg-sign -m "feat: add application lock model"
```

---

### Task 2: Add application lock settings, session lock, and unlock flow

**Files:**
- Create: `test/integration/application_locks_test.rb`
- Create: `app/policies/application_lock_policy.rb`
- Modify: `app/controllers/application_controller.rb`
- Create: `app/controllers/application_locks_controller.rb`
- Modify: `config/routes.rb`
- Modify: `app/views/layouts/application.html.erb`
- Create: `app/views/application_locks/show.html.erb`
- Create: `app/views/application_locks/unlock.html.erb`

- [ ] **Step 1: Write failing integration tests**

Create `test/integration/application_locks_test.rb` covering:

- unauthenticated users are redirected from `application_lock_path` to Devise sign-in;
- a signed-in user enables the lock with current password, PIN, and confirmation;
- a wrong current password does not enable the lock;
- `lock_application_lock_path` locks the session and redirects protected routes to `unlock_application_lock_path`;
- a wrong PIN keeps the session locked;
- a correct PIN unlocks and allows `dashboard_path`;
- disabling the lock with current password destroys the current user's lock.

- [ ] **Step 2: Run integration test RED**

Run: `mise exec -- bin/rails test test/integration/application_locks_test.rb`

Expected: FAIL with missing route/controller or app-lock behavior.

- [ ] **Step 3: Add routes, policy, controller, and enforcement**

Add `resource :application_lock, only: [:show, :create, :destroy] do; post :lock; get :unlock; post :unlock; end`. Add `ApplicationLockPolicy`. In `ApplicationController`, add a before action that redirects signed-in users with an application lock to `unlock_application_lock_path` unless the session is marked unlocked for the current user or the request is the unlock action. In `ApplicationLocksController`, implement settings display, enable with current password and matching six-digit PIN, disable with current password, manual lock, and PIN unlock.

- [ ] **Step 4: Add settings and unlock views**

Add a settings page using existing Flowbite semantic classes and `ButtonComponent`. Add an unlock page with a PIN field, sign-out link, and no hardcoded Tailwind colors outside the project's semantic tokens.

- [ ] **Step 5: Run integration test GREEN**

Run: `mise exec -- bin/rails test test/integration/application_locks_test.rb`

Expected: PASS.

- [ ] **Step 6: Commit application lock flow**

```bash
git add app/controllers/application_controller.rb app/controllers/application_locks_controller.rb app/policies/application_lock_policy.rb app/views/application_locks/show.html.erb app/views/application_locks/unlock.html.erb app/views/layouts/application.html.erb config/routes.rb test/integration/application_locks_test.rb
git commit --no-gpg-sign -m "feat: add application lock flow"
```

---

### Task 3: Verify application lock slice

- [ ] **Step 1: Run focused tests**

Run: `mise exec -- bin/rails test test/models/application_lock_test.rb test/integration/application_locks_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run lint for touched Ruby files**

Run: `mise exec -- bin/rubocop app/models/application_lock.rb app/models/user.rb app/controllers/application_controller.rb app/controllers/application_locks_controller.rb app/policies/application_lock_policy.rb test/models/application_lock_test.rb test/integration/application_locks_test.rb config/routes.rb db/migrate/20260503180000_create_application_locks.rb`

Expected: PASS.

- [ ] **Step 4: Run ERB lint for touched views**

Run: `mise exec -- bundle exec erb_lint app/views/application_locks/show.html.erb app/views/application_locks/unlock.html.erb app/views/layouts/application.html.erb`

Expected: PASS.

- [ ] **Step 5: Perform a visual check**

Start the Rails server in the worktree, sign in as a test user, open `/application_lock`, confirm the settings page renders, enable a PIN, click Lock, confirm the unlock page renders, unlock, and stop the server.

- [ ] **Step 6: Check git status**

Run: `git status --short`

Expected: clean working tree.

---

## Self-Review

- Spec coverage: implements Phase 5 application lock as a separate current-user security resource, not hidden inside Devise login. It protects browser sessions after Devise authentication and stores only a digest.
- Scope control: does not implement source-client local token encryption, WebAuthn app-lock unlock, automatic idle timeout, persisted session list, or mobile PWA-specific behavior; those remain later slices.
- Placeholder scan: no TODO/TBD placeholders remain.
- Type consistency: the plan consistently uses `ApplicationLock`, `ApplicationLocksController`, `application_lock_path`, `lock_application_lock_path`, and `unlock_application_lock_path`.
