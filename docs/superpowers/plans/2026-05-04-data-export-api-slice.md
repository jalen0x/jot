# Data Export API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a token-authenticated API endpoint that exports the current user's transactions as CSV.

**Architecture:** Use `resources :data_exports, only: :create` under `api/v1` because requesting an export creates a downloadable export representation. Reuse the existing `DataExport` service and `DataExportPolicy`; the API controller deliberately skips the JSON-only gate because CSV is the resource representation. Do not add ezBookkeeping legacy `.json` routes, camelCase params, or compatibility envelopes.

**Tech Stack:** Rails 8.1 controller params, HTTP token auth, Pundit, CSV responses, Minitest integration tests.

---

### Task 1: API Contract Tests

**Files:**
- Create: `test/integration/api/v1/data_exports_test.rb`

- [x] **Step 1: Add CSV export test**

Create an API integration test that issues a token, creates one transaction for that user, creates a decoy transaction for another user, calls:

```ruby
post api_v1_data_exports_path,
  headers: csv_headers(raw_token)
```

Expect `200`, `response.media_type == "text/csv"`, a `transactions-YYYY-MM-DD.csv` content disposition, and CSV rows containing only the token owner's transaction comment.

- [x] **Step 2: Add token auth rejection test**

Call `POST /api/v1/data_exports` with `Accept: text/csv` but no bearer token. Expect `401`.

- [x] **Step 3: Run focused test to verify RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/data_exports_test.rb`

Expected: FAIL with missing route/helper or controller because the API resource does not exist yet.

### Task 2: Implementation

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/api/v1/data_exports_controller.rb`

- [x] **Step 1: Add API route**

Inside `namespace :api do namespace :v1 do`, add:

```ruby
resources :data_exports, only: :create
```

- [x] **Step 2: Add API controller**

Create `app/controllers/api/v1/data_exports_controller.rb`:

```ruby
class Api::V1::DataExportsController < ApiController
  skip_before_action :require_json

  # POST /api/v1/data_exports
  def create
    authorize :data_export
    csv = DataExport.new.transactions_csv(user: current_user)

    send_data csv,
      filename: "transactions-#{Time.zone.today.iso8601}.csv",
      type: "text/csv; charset=utf-8"
  end
end
```

- [x] **Step 3: Run focused test to verify GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/data_exports_test.rb`

Expected: PASS.

### Task 3: Verification and Commit

**Files:**
- All touched files from Tasks 1-2.

- [x] **Step 1: Run full test suite**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [x] **Step 2: Run focused RuboCop**

Run: `mise exec -- bin/rubocop config/routes.rb app/controllers/api/v1/data_exports_controller.rb test/integration/api/v1/data_exports_test.rb`

Expected: PASS with no offenses.

- [x] **Step 3: Commit**

Run:

```bash
git add config/routes.rb app/controllers/api/v1/data_exports_controller.rb test/integration/api/v1/data_exports_test.rb docs/superpowers/plans/2026-05-04-data-export-api-slice.md
git commit --no-gpg-sign -m "feat: add data export api"
```
