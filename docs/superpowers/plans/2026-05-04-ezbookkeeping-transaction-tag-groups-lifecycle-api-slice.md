# ezBookkeeping Transaction Tag Groups Lifecycle API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add JSON API support for updating and soft-deleting transaction tag groups.

**Architecture:** Keep the endpoint REST-shaped like the existing Rails rewrite API. The controller remains a thin Pundit-scoped boundary because tag group update is a direct model update with no cross-record ownership assignment.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit policy scopes, prefixed IDs, discard soft deletion.

---

## File Map

- Modify `app/controllers/api/v1/transaction_tag_groups_controller.rb`: add `update` and `destroy` actions.
- Modify `app/policies/transaction_tag_group_policy.rb`: authorize update/destroy for owned tag groups.
- Modify `config/routes.rb`: include `:update` and `:destroy` for API transaction tag groups.
- Modify `test/integration/api/v1/transaction_tag_groups_test.rb`: cover update, destroy, and cross-user boundaries.

## Scope

In scope:
- `PATCH/PUT /api/v1/transaction_tag_groups/:id` with `transaction_tag_group[name]`.
- `DELETE /api/v1/transaction_tag_groups/:id` soft-deletes the group with `discard!`.
- All reads and writes are scoped to the current API token owner.

Out of scope:
- Reordering tag groups.
- Recursive tag changes when a group is deleted.
- Legacy `.json` route aliases such as `v1/transaction/tags/groups/modify.json`.

## Regression Risks Covered

- A tag group can be renamed through the API.
- Another user's tag group cannot be updated or deleted.
- Deleted tag groups are excluded from the existing kept-list endpoint.

---

### Task 1: Add Failing Tests

**Files:**
- Modify: `test/integration/api/v1/transaction_tag_groups_test.rb`

- [ ] **Step 1: Add update test**

Add after the create test:

```ruby
test "updates a transaction tag group for the token owner" do
  user = create(:user)
  tag_group = create_tag_group(user: user, name: "Bills", display_order: 1)
  raw_token = issue_token(user)

  patch api_v1_transaction_tag_group_path(tag_group),
    params: { transaction_tag_group: { name: "Subscriptions" } },
    headers: json_headers(raw_token),
    as: :json

  assert_response :success
  assert_equal "Subscriptions", tag_group.reload.name

  group_json = JSON.parse(response.body).fetch("transaction_tag_group")
  assert_equal tag_group.to_param, group_json.fetch("id")
  assert_equal "Subscriptions", group_json.fetch("name")
  assert_equal 1, group_json.fetch("display_order")
  refute_includes group_json.keys, "user_id"
end
```

- [ ] **Step 2: Add cross-user update test**

Add:

```ruby
test "does not update another user's transaction tag group" do
  user = create(:user)
  other_user = create(:user)
  tag_group = create_tag_group(user: other_user, name: "Other", display_order: 1)
  raw_token = issue_token(user)

  patch api_v1_transaction_tag_group_path(tag_group),
    params: { transaction_tag_group: { name: "Changed" } },
    headers: json_headers(raw_token),
    as: :json

  assert_response :not_found
  assert_equal "Other", tag_group.reload.name
end
```

- [ ] **Step 3: Add delete test**

Add:

```ruby
test "deletes a transaction tag group for the token owner" do
  user = create(:user)
  tag_group = create_tag_group(user: user, name: "Bills", display_order: 1)
  raw_token = issue_token(user)

  delete api_v1_transaction_tag_group_path(tag_group), headers: json_headers(raw_token)

  assert_response :no_content
  assert_empty response.body
  assert_predicate tag_group.reload, :discarded?
end
```

- [ ] **Step 4: Add cross-user delete test**

Add:

```ruby
test "does not delete another user's transaction tag group" do
  user = create(:user)
  other_user = create(:user)
  tag_group = create_tag_group(user: other_user, name: "Other", display_order: 1)
  raw_token = issue_token(user)

  delete api_v1_transaction_tag_group_path(tag_group), headers: json_headers(raw_token)

  assert_response :not_found
  refute_predicate tag_group.reload, :discarded?
end
```

- [ ] **Step 5: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_tag_groups_test.rb
```

Expected: FAIL because member routes are not available yet.

---

### Task 2: Wire Routes, Policy, And Controller

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/policies/transaction_tag_group_policy.rb`
- Modify: `app/controllers/api/v1/transaction_tag_groups_controller.rb`

- [ ] **Step 1: Add routes**

Change in `config/routes.rb`:

```ruby
resources :transaction_tag_groups, only: [ :index, :create ]
```

to:

```ruby
resources :transaction_tag_groups, only: [ :index, :create, :update, :destroy ]
```

- [ ] **Step 2: Add policy authorization**

In `app/policies/transaction_tag_group_policy.rb`, add owned-record checks:

```ruby
def update? = owns_record?
def destroy? = owns_record?

private

def owns_record? = user.present? && record.user_id == user.id
```

- [ ] **Step 3: Add controller actions**

In `app/controllers/api/v1/transaction_tag_groups_controller.rb`, add after `create`:

```ruby
# PATCH/PUT /api/v1/transaction_tag_groups/:id
def update
  tag_group = scoped_tag_group
  authorize tag_group

  if tag_group.update(tag_group_params)
    render json: { transaction_tag_group: tag_group }
  else
    render json: { errors: tag_group.errors.full_messages }, status: :unprocessable_content
  end
end

# DELETE /api/v1/transaction_tag_groups/:id
def destroy
  tag_group = scoped_tag_group
  authorize tag_group
  tag_group.discard!

  head :no_content
end
```

Add this private method:

```ruby
def scoped_tag_group
  policy_scope(TransactionTagGroup).kept.find(params[:id])
end
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_tag_groups_test.rb
```

Expected: PASS.

---

### Task 3: Final Verification And Commit

**Files:**
- All files above

- [ ] **Step 1: Run full Rails tests**

Run:

```bash
mise exec -- bin/rails test
```

Expected: PASS with zero failures/errors.

- [ ] **Step 2: Run targeted RuboCop**

Run:

```bash
mise exec -- bin/rubocop app/controllers/api/v1/transaction_tag_groups_controller.rb app/policies/transaction_tag_group_policy.rb test/integration/api/v1/transaction_tag_groups_test.rb config/routes.rb
```

Expected: `no offenses detected`.

- [ ] **Step 3: Commit implementation**

Run:

```bash
git add app/controllers/api/v1/transaction_tag_groups_controller.rb app/policies/transaction_tag_group_policy.rb config/routes.rb test/integration/api/v1/transaction_tag_groups_test.rb
git commit --no-gpg-sign -m "feat: add transaction tag group lifecycle api"
```

- [ ] **Step 4: Merge back to main after verification**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
git status --short --branch
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-ff --no-gpg-sign feature/ezbookkeeping-transaction-tag-groups-lifecycle-api-slice -m "Merge branch 'feature/ezbookkeeping-transaction-tag-groups-lifecycle-api-slice'"
mise exec -- bin/rails test
```

Expected: merged `main` test suite passes.

- [ ] **Step 5: Cleanup worktree and branch**

Run:

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/ezbookkeeping-transaction-tag-groups-lifecycle-api-slice
git branch -d feature/ezbookkeeping-transaction-tag-groups-lifecycle-api-slice
```
