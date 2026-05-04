# Import Batches API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add token-authenticated API endpoints to create an import batch and fetch its current status.

**Architecture:** Use `resources :import_batches, only: [ :show, :create ]` under `api/v1`; import batches are addressable resources after creation but do not need index/update/delete in this slice. Reuse `ImportBatchParserJob`, `ImportBatchPolicy`, and current-user scoping; keep CSV parsing asynchronous through Solid Queue rather than running it inline in the controller. Do not add ezBookkeeping legacy `.json` routes, camelCase params, or compatibility envelopes.

**Tech Stack:** Rails 8.1 controller params, HTTP token auth, Pundit, ActiveJob test adapter, Minitest integration tests.

---

### Task 1: API Contract Tests

**Files:**
- Create: `test/integration/api/v1/import_batches_test.rb`

- [x] **Step 1: Add create test**

Create an API integration test that posts string params under `import_batch` with `source_filename` and `raw_csv`. Expect `201`, one persisted import batch for the token owner, status `pending`, JSON wrapper `import_batch`, and an enqueued `ImportBatchParserJob` with the batch ID.

- [x] **Step 2: Add show and ownership tests**

Cover `GET /api/v1/import_batches/:id` for the token owner's batch, asserting `id`, `source_filename`, `status`, `imported_count`, and `error_message`. Cover not showing another user's batch with `404`.

- [x] **Step 3: Add invalid create test**

Post `raw_csv: ""` and expect `422`, no persisted batch, and an error mentioning raw csv.

- [x] **Step 4: Run focused test to verify RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/import_batches_test.rb`

Expected: FAIL with missing route/helper or controller because the API resource does not exist yet.

### Task 2: Implementation

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/api/v1/import_batches_controller.rb`
- Modify: `app/models/import_batch.rb`

- [x] **Step 1: Add API route**

Inside `namespace :api do namespace :v1 do`, add:

```ruby
resources :import_batches, only: [ :show, :create ]
```

- [x] **Step 2: Add JSON shape**

In `app/models/import_batch.rb`, add:

```ruby
def as_json(_options = {})
  {
    id: to_param,
    source_filename: source_filename,
    status: status,
    imported_count: imported_count,
    error_message: error_message
  }
end
```

- [x] **Step 3: Add API controller**

Create `app/controllers/api/v1/import_batches_controller.rb` with `show` scoped through `policy_scope(ImportBatch).find(params[:id])`, `create` through `current_user.import_batches.build(import_batch_params)`, `ImportBatchParserJob.perform_later(import_batch.id)` after save, `status: :created` for success, and `status: :unprocessable_content` for validation failures.

- [x] **Step 4: Run focused test to verify GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/import_batches_test.rb`

Expected: PASS.

### Task 3: Verification and Commit

**Files:**
- All touched files from Tasks 1-2.

- [x] **Step 1: Run full test suite**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [x] **Step 2: Run focused RuboCop**

Run: `mise exec -- bin/rubocop config/routes.rb app/controllers/api/v1/import_batches_controller.rb app/models/import_batch.rb test/integration/api/v1/import_batches_test.rb`

Expected: PASS with no offenses.

- [x] **Step 3: Commit**

Run:

```bash
git add config/routes.rb app/controllers/api/v1/import_batches_controller.rb app/models/import_batch.rb test/integration/api/v1/import_batches_test.rb docs/superpowers/plans/2026-05-04-import-batches-api-slice.md
git commit --no-gpg-sign -m "feat: add import batches api"
```
