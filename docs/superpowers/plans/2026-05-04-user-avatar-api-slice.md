# User Avatar API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add token-authenticated Rails-native API endpoints for uploading and removing the current user's avatar.

**Architecture:** Source ezBookkeeping has avatar update/remove endpoints; Rails will expose the current user's avatar as singular `POST/DELETE /api/v1/user_avatar`. Active Storage remains the attachment boundary through `User#avatar`, and responses reuse the existing `UserProfile` JSON resource. This slice does not add legacy `.json` paths, public avatar proxy URLs, image processing, or frontend UI.

**Tech Stack:** Rails 8.1 routing/controllers, Active Storage, HTTP token auth via `ApiController`, Pundit, Minitest integration tests.

---

### Task 1: API Contract Tests

**Files:**
- Create: `test/integration/api/v1/user_avatars_test.rb`
- Create: `test/fixtures/files/avatar.png`

- [x] **Step 1: Add upload and removal tests**

Create `test/fixtures/files/avatar.png` with a tiny placeholder file:

```text
avatar image placeholder
```

Create `test/integration/api/v1/user_avatars_test.rb`:

```ruby
require "test_helper"

class ApiV1UserAvatarsTest < ActionDispatch::IntegrationTest
  test "uploads the token owner's avatar" do
    user = create(:user)
    other_user = create(:user)
    other_user.avatar.attach(io: StringIO.new("other"), filename: "other.png", content_type: "image/png", identify: false)
    raw_token = issue_token(user)

    post api_v1_user_avatar_path,
      params: { avatar: fixture_file_upload("avatar.png", "image/png") },
      headers: json_headers(raw_token)

    assert_response :created
    assert_predicate user.reload.avatar, :attached?
    assert_predicate other_user.reload.avatar, :attached?
    body = JSON.parse(response.body)
    assert_equal [ "user_profile" ], body.keys
    profile = body.fetch("user_profile")
    assert_equal true, profile.fetch("avatar_attached")
    refute_includes profile.keys, "user_id"
  end

  test "removes the token owner's avatar" do
    user = create(:user)
    user.avatar.attach(io: StringIO.new("avatar"), filename: "avatar.png", content_type: "image/png", identify: false)
    other_user = create(:user)
    other_user.avatar.attach(io: StringIO.new("other"), filename: "other.png", content_type: "image/png", identify: false)
    raw_token = issue_token(user)

    delete api_v1_user_avatar_path, headers: json_headers(raw_token)

    assert_response :no_content
    assert_empty response.body
    refute_predicate user.reload.avatar, :attached?
    assert_predicate other_user.reload.avatar, :attached?
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
mise exec -- bin/rails test test/integration/api/v1/user_avatars_test.rb
```

Expected: FAIL because `api_v1_user_avatar_path` does not exist yet.

### Task 2: Implementation

**Files:**
- Modify: `config/routes.rb`
- Create: `app/policies/user_avatar_policy.rb`
- Create: `app/controllers/api/v1/user_avatars_controller.rb`

- [x] **Step 1: Add the singleton route**

Inside `namespace :api do namespace :v1 do`, add:

```ruby
resource :user_avatar, only: [ :create, :destroy ]
```

- [x] **Step 2: Add Pundit policy**

Create `app/policies/user_avatar_policy.rb`:

```ruby
class UserAvatarPolicy < ApplicationPolicy
  def create? = user.present?
  def destroy? = user.present?
end
```

- [x] **Step 3: Add API controller**

Create `app/controllers/api/v1/user_avatars_controller.rb`:

```ruby
class Api::V1::UserAvatarsController < ApiController
  # POST /api/v1/user_avatar
  def create
    authorize :user_avatar
    current_user.avatar.attach(avatar_attachable)

    render json: { user_profile: UserProfile.new(current_user) }, status: :created
  end

  # DELETE /api/v1/user_avatar
  def destroy
    authorize :user_avatar
    current_user.avatar.purge if current_user.avatar.attached?

    head :no_content
  end

  private

  def avatar_attachable
    file = params.expect(:avatar)
    return file unless file.respond_to?(:tempfile)

    {
      io: file.tempfile,
      filename: file.original_filename,
      content_type: file.content_type,
      identify: false
    }
  end
end
```

- [x] **Step 4: Verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/user_avatars_test.rb test/integration/api/v1/user_profiles_test.rb
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
mise exec -- bin/rubocop config/routes.rb app/policies/user_avatar_policy.rb app/controllers/api/v1/user_avatars_controller.rb test/integration/api/v1/user_avatars_test.rb
```

Expected: no offenses.

- [x] **Step 3: Commit implementation**

Run:

```bash
git add docs/superpowers/plans/2026-05-04-user-avatar-api-slice.md config/routes.rb app/policies/user_avatar_policy.rb app/controllers/api/v1/user_avatars_controller.rb test/integration/api/v1/user_avatars_test.rb test/fixtures/files/avatar.png
git commit --no-gpg-sign -m "feat: add user avatar api"
```

- [x] **Step 4: Merge back to local main**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-gpg-sign --no-ff feature/user-avatar-api-slice
mise exec -- bin/rails test
```

- [x] **Step 5: Cleanup worktree**

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/user-avatar-api-slice
git branch -d feature/user-avatar-api-slice
```
