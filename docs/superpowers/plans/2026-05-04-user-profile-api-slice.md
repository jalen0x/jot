# User Profile API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a token-authenticated Rails-native API resource for reading and updating the current user's display profile.

**Architecture:** Source ezBookkeeping has profile get/update endpoints; Rails will expose the current user's profile as singular `GET/PATCH /api/v1/user_profile`. A small Active Model-style `UserProfile` resource owns JSON shape and delegates persistence to `User`. This slice intentionally excludes avatar upload/removal, password changes, email changes, legacy `.json` paths, camelCase params, and source response envelopes.

**Tech Stack:** Rails 8.1 routing/controllers, HTTP token auth via `ApiController`, Pundit, Active Model-style resource object, Minitest integration tests.

---

### Task 1: API Contract Tests

**Files:**
- Create: `test/integration/api/v1/user_profiles_test.rb`

- [x] **Step 1: Add show and update tests**

Create `test/integration/api/v1/user_profiles_test.rb`:

```ruby
require "test_helper"

class ApiV1UserProfilesTest < ActionDispatch::IntegrationTest
  test "shows the token owner's profile" do
    user = create(:user, email: "jalen@example.com", first_name: "Jalen", last_name: "X")
    raw_token = issue_token(user)

    get api_v1_user_profile_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "user_profile" ], body.keys
    profile = body.fetch("user_profile")
    assert_equal "jalen@example.com", profile.fetch("email")
    assert_equal "Jalen", profile.fetch("first_name")
    assert_equal "X", profile.fetch("last_name")
    assert_equal "Jalen X", profile.fetch("name")
    assert_equal false, profile.fetch("avatar_attached")
    refute_includes profile.keys, "user_id"
    refute_includes profile.keys, "encrypted_password"
  end

  test "updates only display profile attributes" do
    user = create(:user, email: "jalen@example.com", first_name: "Old", last_name: "Name")
    raw_token = issue_token(user)

    patch api_v1_user_profile_path,
      params: { user_profile: { first_name: "New", last_name: "Display", email: "changed@example.com" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :success
    body = JSON.parse(response.body)
    profile = body.fetch("user_profile")
    assert_equal "New", profile.fetch("first_name")
    assert_equal "Display", profile.fetch("last_name")
    assert_equal "New Display", profile.fetch("name")
    assert_equal "jalen@example.com", profile.fetch("email")
    user.reload
    assert_equal "New", user.first_name
    assert_equal "Display", user.last_name
    assert_equal "jalen@example.com", user.email
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
end
```

- [x] **Step 2: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/user_profiles_test.rb
```

Expected: FAIL because `api_v1_user_profile_path` does not exist yet.

### Task 2: Implementation

**Files:**
- Modify: `config/routes.rb`
- Create: `app/models/user_profile.rb`
- Create: `app/policies/user_profile_policy.rb`
- Create: `app/controllers/api/v1/user_profiles_controller.rb`

- [x] **Step 1: Add the singleton route**

Inside `namespace :api do namespace :v1 do`, add:

```ruby
resource :user_profile, only: [ :show, :update ]
```

- [x] **Step 2: Add profile resource object**

Create `app/models/user_profile.rb`:

```ruby
class UserProfile
  delegate :email, :first_name, :last_name, :name, :avatar, :errors, to: :user

  def initialize(user)
    @user = user
  end

  def update(attributes)
    user.update(attributes)
  end

  def as_json(_options = {})
    {
      email: email,
      first_name: first_name,
      last_name: last_name,
      name: name.to_s,
      avatar_attached: avatar.attached?
    }
  end

  private

  attr_reader :user
end
```

- [x] **Step 3: Add Pundit policy**

Create `app/policies/user_profile_policy.rb`:

```ruby
class UserProfilePolicy < ApplicationPolicy
  def show? = user.present?
  def update? = user.present?
end
```

- [x] **Step 4: Add API controller**

Create `app/controllers/api/v1/user_profiles_controller.rb`:

```ruby
class Api::V1::UserProfilesController < ApiController
  # GET /api/v1/user_profile
  def show
    authorize :user_profile

    render json: { user_profile: user_profile }
  end

  # PATCH/PUT /api/v1/user_profile
  def update
    authorize :user_profile

    if user_profile.update(user_profile_params)
      render json: { user_profile: user_profile }
    else
      render json: { errors: user_profile.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def user_profile
    @user_profile ||= UserProfile.new(current_user)
  end

  def user_profile_params
    params.expect(user_profile: [ :first_name, :last_name ])
  end
end
```

- [x] **Step 5: Verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/user_profiles_test.rb
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
mise exec -- bin/rubocop config/routes.rb app/models/user_profile.rb app/policies/user_profile_policy.rb app/controllers/api/v1/user_profiles_controller.rb test/integration/api/v1/user_profiles_test.rb
```

Expected: no offenses.

- [x] **Step 3: Commit implementation**

Run:

```bash
git add docs/superpowers/plans/2026-05-04-user-profile-api-slice.md config/routes.rb app/models/user_profile.rb app/policies/user_profile_policy.rb app/controllers/api/v1/user_profiles_controller.rb test/integration/api/v1/user_profiles_test.rb
git commit --no-gpg-sign -m "feat: add user profile api"
```

- [x] **Step 4: Merge back to local main**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-gpg-sign --no-ff feature/user-profile-api-slice
mise exec -- bin/rails test
```

- [x] **Step 5: Cleanup worktree**

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/user-profile-api-slice
git branch -d feature/user-profile-api-slice
```
