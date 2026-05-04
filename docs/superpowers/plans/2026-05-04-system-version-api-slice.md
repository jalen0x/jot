# System Version API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a token-authenticated Rails-native API resource that reports the running app version metadata.

**Architecture:** Source ezBookkeeping exposes `/api/v1/systems/version.json`; Rails will expose a canonical singleton resource at `GET /api/v1/system_version`. The controller stays thin, Pundit authorizes the resource, and a plain model-like object owns the JSON shape. This slice does not add legacy `.json` routes, camelCase keys, public unauthenticated access, or release-management automation.

**Tech Stack:** Rails 8.1 routing/controllers, HTTP token auth via `ApiController`, Pundit, Minitest integration tests.

---

### Task 1: API Contract Test

**Files:**
- Create: `test/integration/api/v1/system_versions_test.rb`

- [x] **Step 1: Add the failing integration test**

Create `test/integration/api/v1/system_versions_test.rb`:

```ruby
require "test_helper"

class ApiV1SystemVersionsTest < ActionDispatch::IntegrationTest
  test "shows version metadata for the token owner" do
    user = create(:user)
    raw_token = issue_token(user)

    with_env(
      "APP_VERSION" => "2026.5.4",
      "APP_COMMIT_HASH" => "abc123",
      "APP_BUILD_TIME" => "2026-05-04T10:00:00Z"
    ) do
      get api_v1_system_version_path, headers: json_headers(raw_token)
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "system_version" ], body.keys
    system_version = body.fetch("system_version")
    assert_equal "2026.5.4", system_version.fetch("version")
    assert_equal "abc123", system_version.fetch("commit_hash")
    assert_equal "2026-05-04T10:00:00Z", system_version.fetch("build_time")
    refute_includes system_version.keys, "user_id"
  end

  private

  def issue_token(user)
    ApiTokenIssuer.new.issue(user: user, attributes: { name: "Auth", expires_in_days: "" }).raw_token
  end

  def json_headers(raw_token)
    {
      "Accept" => "application/json",
      "Authorization" => "Bearer #{raw_token}"
    }
  end

  def with_env(values)
    original = values.keys.to_h { |key| [ key, ENV[key] ] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
```

- [x] **Step 2: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/system_versions_test.rb
```

Expected: FAIL because `api_v1_system_version_path` does not exist yet.

### Task 2: Implementation

**Files:**
- Modify: `config/routes.rb`
- Create: `app/models/system_version.rb`
- Create: `app/policies/system_version_policy.rb`
- Create: `app/controllers/api/v1/system_versions_controller.rb`

- [x] **Step 1: Add the singleton route**

Inside `namespace :api do namespace :v1 do`, add:

```ruby
resource :system_version, only: :show
```

- [x] **Step 2: Add the model-like JSON resource**

Create `app/models/system_version.rb`:

```ruby
class SystemVersion
  def self.current
    new(
      version: ENV.fetch("APP_VERSION", "development"),
      commit_hash: ENV["APP_COMMIT_HASH"],
      build_time: ENV["APP_BUILD_TIME"]
    )
  end

  attr_reader :version, :commit_hash, :build_time

  def initialize(version:, commit_hash:, build_time:)
    @version = version
    @commit_hash = commit_hash
    @build_time = build_time
  end

  def as_json(_options = {})
    {
      version: version,
      commit_hash: commit_hash,
      build_time: build_time
    }.compact
  end
end
```

- [x] **Step 3: Add Pundit policy**

Create `app/policies/system_version_policy.rb`:

```ruby
class SystemVersionPolicy < ApplicationPolicy
  def show? = user.present?
end
```

- [x] **Step 4: Add API controller**

Create `app/controllers/api/v1/system_versions_controller.rb`:

```ruby
class Api::V1::SystemVersionsController < ApiController
  # GET /api/v1/system_version
  def show
    authorize :system_version

    render json: { system_version: SystemVersion.current }
  end
end
```

- [x] **Step 5: Verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/system_versions_test.rb
```

Expected: PASS.

### Task 3: Verification And Merge

**Files:**
- All files touched in Tasks 1-2.

- [x] **Step 1: Run full Rails tests**

Run:

```bash
mise exec -- bin/rails test
```

Expected: 0 failures, 0 errors.

- [x] **Step 2: Run targeted RuboCop**

Run:

```bash
mise exec -- bin/rubocop config/routes.rb app/models/system_version.rb app/policies/system_version_policy.rb app/controllers/api/v1/system_versions_controller.rb test/integration/api/v1/system_versions_test.rb
```

Expected: no offenses.

- [x] **Step 3: Commit implementation**

Run:

```bash
git add docs/superpowers/plans/2026-05-04-system-version-api-slice.md config/routes.rb app/models/system_version.rb app/policies/system_version_policy.rb app/controllers/api/v1/system_versions_controller.rb test/integration/api/v1/system_versions_test.rb
git commit --no-gpg-sign -m "feat: add system version api"
```

- [x] **Step 4: Merge back to local main**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-gpg-sign --no-ff feature/system-version-api-slice
mise exec -- bin/rails test
```

- [x] **Step 5: Cleanup worktree**

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/system-version-api-slice
git branch -d feature/system-version-api-slice
```
