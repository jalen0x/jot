# Insight Explorers API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Rails-native Insight Explorer resource for saving bounded chart/filter configurations per user.

**Architecture:** Store saved explorers in `insight_explorers` with `jsonb` config, soft-delete via Discard, and expose standard `api/v1/insight_explorers` CRUD. The Rails rewrite stores data as bounded inert JSON configuration; it does not evaluate code, implement the old explorer query language, or add ezBookkeeping legacy `.json` routes/camelCase/envelopes. Create assigns display order from the token owner's kept explorers; update may change normal fields directly.

**Tech Stack:** Rails 8.1, PostgreSQL `jsonb`, Discard, Prefixed IDs, Pundit, Minitest integration/model tests.

---

### Task 1: Model Contract Tests

**Files:**
- Create: `test/models/insight_explorer_test.rb`

- [x] **Step 1: Add model tests**

Cover:
- valid explorer normalizes name and stores hash config
- rejects blank name
- rejects non-object config
- rejects config larger than 32 KB
- `as_json` exposes `id`, `name`, `display_order`, `hidden`, and `config` only

- [x] **Step 2: Run model test to verify RED**

Run: `mise exec -- bin/rails test test/models/insight_explorer_test.rb`

Expected: FAIL with `uninitialized constant InsightExplorer`.

### Task 2: API Contract Tests

**Files:**
- Create: `test/integration/api/v1/insight_explorers_test.rb`

- [x] **Step 1: Add index and show tests**

Cover index listing only token owner's kept explorers ordered by `display_order, name`, excluding discarded and other-user rows. Cover show for an owned explorer and not showing another user's explorer.

- [x] **Step 2: Add create and update tests**

Cover create with snake_case params `name`, `config`, `hidden`; expect `201`, normalized persisted name, next display order, and config JSON. Cover update changing `name`, `config`, `hidden`, and `display_order`.

- [x] **Step 3: Add validation and destroy tests**

Cover invalid create with blank name returning `422`. Cover destroy soft-deleting an owned explorer and not deleting another user's explorer.

- [x] **Step 4: Run API test to verify RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/insight_explorers_test.rb`

Expected: FAIL with missing route/helper/model.

### Task 3: Implementation

**Files:**
- Create: `db/migrate/20260504100000_create_insight_explorers.rb`
- Modify: `db/structure.sql`
- Create: `app/models/insight_explorer.rb`
- Create: `app/policies/insight_explorer_policy.rb`
- Create: `app/controllers/api/v1/insight_explorers_controller.rb`
- Modify: `app/models/user.rb`
- Modify: `config/routes.rb`

- [x] **Step 1: Add migration and run it**

Create `db/migrate/20260504100000_create_insight_explorers.rb` with `user_id`, `name`, `config` jsonb default `{}`, `hidden`, `display_order`, `discarded_at`, timestamps, and indexes on user/display order and discarded state.

Run: `mise exec -- bin/rails db:migrate`

Expected: migration succeeds and updates `db/structure.sql`.

- [x] **Step 2: Add model and user association**

Create `app/models/insight_explorer.rb` with `include Discard::Model`, `has_prefix_id :ixp`, ownership, normalization, validations, config object/size checks, and `as_json`.

Modify `app/models/user.rb` with:

```ruby
has_many :insight_explorers, dependent: :restrict_with_error
```

- [x] **Step 3: Add policy**

Create `app/policies/insight_explorer_policy.rb` with signed-in index/create and owner show/update/destroy, plus a scope resolving `scope.where(user: user)`.

- [x] **Step 4: Add route and controller**

Add `resources :insight_explorers, only: [ :index, :show, :create, :update, :destroy ]` under `api/v1` and create a controller with standard current-user-scoped CRUD. Create assigns `display_order` to `current_user.insight_explorers.kept.maximum(:display_order).to_i + 1`.

- [x] **Step 5: Run focused tests to verify GREEN**

Run: `mise exec -- bin/rails test test/models/insight_explorer_test.rb test/integration/api/v1/insight_explorers_test.rb`

Expected: PASS.

### Task 4: Verification and Commit

**Files:**
- All touched files from Tasks 1-3.

- [x] **Step 1: Run full test suite**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [x] **Step 2: Run focused RuboCop**

Run: `mise exec -- bin/rubocop db/migrate/20260504100000_create_insight_explorers.rb app/models/insight_explorer.rb app/models/user.rb app/policies/insight_explorer_policy.rb app/controllers/api/v1/insight_explorers_controller.rb config/routes.rb test/models/insight_explorer_test.rb test/integration/api/v1/insight_explorers_test.rb`

Expected: PASS with no offenses.

- [x] **Step 3: Commit**

Run:

```bash
git add db/migrate/20260504100000_create_insight_explorers.rb db/structure.sql app/models/insight_explorer.rb app/models/user.rb app/policies/insight_explorer_policy.rb app/controllers/api/v1/insight_explorers_controller.rb config/routes.rb test/models/insight_explorer_test.rb test/integration/api/v1/insight_explorers_test.rb docs/superpowers/plans/2026-05-04-insight-explorers-api-slice.md
git commit --no-gpg-sign -m "feat: add insight explorers api"
```
