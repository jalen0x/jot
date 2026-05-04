# User Preference API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modern JSON API resource for reading and updating the token owner's default user preference currency.

**Architecture:** Use a singleton `resource :user_preference` under `api/v1` because the current API token identifies exactly one preference resource and no `:id` is needed. Keep the HTTP boundary in `Api::V1::UserPreferencesController`, reuse the existing `UserPreferencePolicy`, and define the JSON shape on `UserPreference#as_json`. Do not add ezBookkeeping legacy `.json` routes, camelCase params, or compatibility envelopes.

**Tech Stack:** Rails 8.1 controller params, HTTP token auth, Pundit, Minitest integration tests.

---

### Task 1: API Contract Tests

**Files:**
- Create: `test/integration/api/v1/user_preferences_test.rb`

- [x] **Step 1: Add show test**

Create an API integration test that issues a token for a user with `default_currency_code: "EUR"`, creates a decoy preference for another user, calls `GET /api/v1/user_preference`, and expects:

```ruby
assert_response :success
assert_equal [ "user_preference" ], body.keys
assert_equal "EUR", body.fetch("user_preference").fetch("default_currency_code")
refute_includes body.fetch("user_preference").keys, "user_id"
```

- [x] **Step 2: Add update/create test**

Patch `PATCH /api/v1/user_preference` with real wire params:

```ruby
params: { user_preference: { default_currency_code: "cad" } }
```

Expect `200`, persisted `current_user.user_preference.default_currency_code == "CAD"`, and response JSON `default_currency_code == "CAD"`.

- [x] **Step 3: Add invalid update test**

Start with an existing `USD` preference, patch `default_currency_code: "USDD"`, expect `422`, the persisted preference remains `USD`, and response errors mention default currency.

- [x] **Step 4: Run focused test to verify RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/user_preferences_test.rb`

Expected: FAIL with missing route/helper or controller because the API resource does not exist yet.

### Task 2: Implementation

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/api/v1/user_preferences_controller.rb`
- Modify: `app/models/user_preference.rb`

- [x] **Step 1: Add singleton API route**

Inside `namespace :api do namespace :v1 do`, add:

```ruby
resource :user_preference, only: [ :show, :update ]
```

- [x] **Step 2: Add resource JSON shape**

In `app/models/user_preference.rb`, add:

```ruby
def as_json(_options = {})
  {
    default_currency_code: default_currency_code
  }
end
```

- [x] **Step 3: Add API controller**

Create `app/controllers/api/v1/user_preferences_controller.rb`:

```ruby
class Api::V1::UserPreferencesController < ApiController
  # GET /api/v1/user_preference
  def show
    authorize :user_preference

    render json: { user_preference: user_preference }
  end

  # PATCH/PUT /api/v1/user_preference
  def update
    authorize :user_preference

    if user_preference.update(user_preference_params)
      render json: { user_preference: user_preference }
    else
      render json: { errors: user_preference.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def user_preference
    @user_preference ||= current_user.user_preference || current_user.build_user_preference(default_currency_code: "USD")
  end

  def user_preference_params
    params.expect(user_preference: [ :default_currency_code ])
  end
end
```

- [x] **Step 4: Run focused test to verify GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/user_preferences_test.rb`

Expected: PASS.

### Task 3: Verification and Commit

**Files:**
- All touched files from Tasks 1-2.

- [x] **Step 1: Run full test suite**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [x] **Step 2: Run focused RuboCop**

Run: `mise exec -- bin/rubocop config/routes.rb app/controllers/api/v1/user_preferences_controller.rb app/models/user_preference.rb test/integration/api/v1/user_preferences_test.rb`

Expected: PASS with no offenses.

- [x] **Step 3: Commit**

Run:

```bash
git add config/routes.rb app/controllers/api/v1/user_preferences_controller.rb app/models/user_preference.rb test/integration/api/v1/user_preferences_test.rb docs/superpowers/plans/2026-05-04-user-preference-api-slice.md
git commit --no-gpg-sign -m "feat: add user preference api"
```
