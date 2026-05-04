# ezBookkeeping Transaction Tags Lifecycle API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add JSON API support for updating, hiding, ungrouping, regrouping, and soft-deleting transaction tags.

**Architecture:** Keep the API REST-shaped like the existing Rails rewrite endpoints. Add a focused `TransactionTagUpdater` service for owned tag-group assignment and model validation; keep the controller as a thin boundary that scopes tags through Pundit and delegates update/delete work.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit policy scopes, prefixed IDs, discard soft deletion.

---

## File Map

- Create `app/services/transaction_tag_updater.rb`: update tag name, hidden flag, and optional group with ownership validation.
- Modify `app/controllers/api/v1/transaction_tags_controller.rb`: add `update` and `destroy` actions.
- Modify `app/policies/transaction_tag_policy.rb`: authorize update/destroy for owned tags.
- Modify `config/routes.rb`: include `:update` and `:destroy` for API transaction tags.
- Modify `test/integration/api/v1/transaction_tags_test.rb`: cover update, ungroup, destroy, cross-user update/delete, and another user's group rejection.

## Scope

In scope:
- `PATCH/PUT /api/v1/transaction_tags/:id` with `transaction_tag[name]`, `transaction_tag[transaction_tag_group_id]`, and `transaction_tag[hidden]`.
- Empty `transaction_tag_group_id` removes the tag from its group.
- `DELETE /api/v1/transaction_tags/:id` soft-deletes the tag with `discard!`.
- All reads and writes are scoped to the current API token owner.

Out of scope:
- Transaction tag group update/delete endpoints.
- Reordering tags.
- Removing historical taggings when a tag is deleted.
- Legacy `.json` route aliases such as `v1/transaction/tags/modify.json`.

## Regression Risks Covered

- Tags can be hidden without disappearing from historical transaction taggings.
- A tag can be moved to a user-owned group or ungrouped.
- Another user's tag cannot be updated or deleted.
- Another user's tag group cannot be assigned.
- Deleted tags are excluded from the existing kept-list endpoint.

---

### Task 1: Add Failing Tests

**Files:**
- Modify: `test/integration/api/v1/transaction_tags_test.rb`

- [ ] **Step 1: Add update test**

Add after the create test:

```ruby
test "updates a transaction tag for the token owner" do
  user = create(:user)
  old_group = create_tag_group(user: user, name: "Food", display_order: 1)
  new_group = create_tag_group(user: user, name: "Travel", display_order: 2)
  tag = create_tag(user: user, name: "Meals", display_order: 1, transaction_tag_group: old_group)
  raw_token = issue_token(user)

  patch api_v1_transaction_tag_path(tag),
    params: {
      transaction_tag: {
        name: "Flights",
        transaction_tag_group_id: new_group.to_param,
        hidden: "true"
      }
    },
    headers: json_headers(raw_token),
    as: :json

  assert_response :success
  tag.reload
  assert_equal "Flights", tag.name
  assert_equal new_group, tag.transaction_tag_group
  assert_equal true, tag.hidden

  tag_json = JSON.parse(response.body).fetch("transaction_tag")
  assert_equal tag.to_param, tag_json.fetch("id")
  assert_equal "Flights", tag_json.fetch("name")
  assert_equal new_group.to_param, tag_json.fetch("transaction_tag_group_id")
  assert_equal true, tag_json.fetch("hidden")
  refute_includes tag_json.keys, "user_id"
end
```

- [ ] **Step 2: Add ungroup test**

Add:

```ruby
test "ungroups a transaction tag" do
  user = create(:user)
  group = create_tag_group(user: user, name: "Food", display_order: 1)
  tag = create_tag(user: user, name: "Meals", display_order: 1, transaction_tag_group: group)
  raw_token = issue_token(user)

  patch api_v1_transaction_tag_path(tag),
    params: {
      transaction_tag: {
        name: "Meals",
        transaction_tag_group_id: "",
        hidden: "false"
      }
    },
    headers: json_headers(raw_token),
    as: :json

  assert_response :success
  assert_nil tag.reload.transaction_tag_group
  assert_nil JSON.parse(response.body).fetch("transaction_tag").fetch("transaction_tag_group_id")
end
```

- [ ] **Step 3: Add unavailable group test for update**

Add:

```ruby
test "rejects another user's transaction tag group on update" do
  user = create(:user)
  tag = create_tag(user: user, name: "Meals", display_order: 1)
  other_group = create_tag_group(user: create(:user), name: "Other Food", display_order: 1)
  raw_token = issue_token(user)

  patch api_v1_transaction_tag_path(tag),
    params: {
      transaction_tag: {
        name: "Meals",
        transaction_tag_group_id: other_group.to_param,
        hidden: "false"
      }
    },
    headers: json_headers(raw_token),
    as: :json

  assert_response :unprocessable_content
  assert_nil tag.reload.transaction_tag_group
  assert_match(/Transaction tag group is unavailable/i, response.body)
end
```

- [ ] **Step 4: Add cross-user update test**

Add:

```ruby
test "does not update another user's transaction tag" do
  user = create(:user)
  other_user = create(:user)
  tag = create_tag(user: other_user, name: "Other", display_order: 1)
  raw_token = issue_token(user)

  patch api_v1_transaction_tag_path(tag),
    params: { transaction_tag: { name: "Changed", transaction_tag_group_id: "", hidden: "true" } },
    headers: json_headers(raw_token),
    as: :json

  assert_response :not_found
  assert_equal "Other", tag.reload.name
  assert_equal false, tag.hidden
end
```

- [ ] **Step 5: Add delete test**

Add:

```ruby
test "deletes a transaction tag for the token owner" do
  user = create(:user)
  tag = create_tag(user: user, name: "Meals", display_order: 1)
  raw_token = issue_token(user)

  delete api_v1_transaction_tag_path(tag), headers: json_headers(raw_token)

  assert_response :no_content
  assert_empty response.body
  assert_predicate tag.reload, :discarded?
end
```

- [ ] **Step 6: Add cross-user delete test**

Add:

```ruby
test "does not delete another user's transaction tag" do
  user = create(:user)
  other_user = create(:user)
  tag = create_tag(user: other_user, name: "Other", display_order: 1)
  raw_token = issue_token(user)

  delete api_v1_transaction_tag_path(tag), headers: json_headers(raw_token)

  assert_response :not_found
  refute_predicate tag.reload, :discarded?
end
```

- [ ] **Step 7: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_tags_test.rb
```

Expected: FAIL because member routes are not available yet.

---

### Task 2: Implement TransactionTagUpdater

**Files:**
- Create: `app/services/transaction_tag_updater.rb`

- [ ] **Step 1: Create service**

Create `app/services/transaction_tag_updater.rb`:

```ruby
class TransactionTagUpdater
  def update_tag(tag:, attributes:)
    attributes = attributes.to_h.symbolize_keys
    tag.assign_attributes(tag_attributes(attributes))
    tag.transaction_tag_group = transaction_tag_group_for(tag, attributes[:transaction_tag_group_id])

    return Result.new(updated: false, tag: tag) if tag.errors.any? || !tag.valid?

    tag.save!
    Result.new(updated: true, tag: tag)
  end

  private

  def tag_attributes(attributes)
    {
      name: attributes[:name],
      hidden: ActiveModel::Type::Boolean.new.cast(attributes[:hidden])
    }
  end

  def transaction_tag_group_for(tag, group_id)
    return if group_id.blank?

    tag.user.transaction_tag_groups.kept.find(decoded_id(tag.user.transaction_tag_groups.kept, group_id))
  rescue ActiveRecord::RecordNotFound
    tag.errors.add(:transaction_tag_group, "is unavailable")
    nil
  end

  def decoded_id(scope, id)
    scope.klass.decode_prefix_id(id) || id
  end

  class Result
    attr_reader :tag

    def initialize(updated:, tag:)
      @updated = updated
      @tag = tag
    end

    def updated? = @updated
  end
end
```

- [ ] **Step 2: Run focused test**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_tags_test.rb
```

Expected: still FAIL because controller/routes are not wired.

---

### Task 3: Wire Routes, Policy, And Controller

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/policies/transaction_tag_policy.rb`
- Modify: `app/controllers/api/v1/transaction_tags_controller.rb`

- [ ] **Step 1: Add routes**

Change in `config/routes.rb`:

```ruby
resources :transaction_tags, only: [ :index, :create ]
```

to:

```ruby
resources :transaction_tags, only: [ :index, :create, :update, :destroy ]
```

- [ ] **Step 2: Add policy authorization**

In `app/policies/transaction_tag_policy.rb`, add owned-record checks:

```ruby
def update? = owns_record?
def destroy? = owns_record?

private

def owns_record? = user.present? && record.user_id == user.id
```

- [ ] **Step 3: Add controller actions**

In `app/controllers/api/v1/transaction_tags_controller.rb`, add after `create`:

```ruby
# PATCH/PUT /api/v1/transaction_tags/:id
def update
  tag = scoped_tag
  authorize tag
  result = TransactionTagUpdater.new.update_tag(tag: tag, attributes: tag_params)

  if result.updated?
    render json: { transaction_tag: result.tag }
  else
    render json: { errors: result.tag.errors.full_messages }, status: :unprocessable_content
  end
end

# DELETE /api/v1/transaction_tags/:id
def destroy
  tag = scoped_tag
  authorize tag
  tag.discard!

  head :no_content
end
```

Add this private method:

```ruby
def scoped_tag
  policy_scope(TransactionTag).kept.find(params[:id])
end
```

Update `tag_params` from:

```ruby
@tag_params ||= params.expect(transaction_tag: [ :name, :transaction_tag_group_id ])
```

to:

```ruby
@tag_params ||= params.expect(transaction_tag: [ :name, :transaction_tag_group_id, :hidden ])
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_tags_test.rb
```

Expected: PASS.

---

### Task 4: Final Verification And Commit

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
mise exec -- bin/rubocop app/services/transaction_tag_updater.rb app/controllers/api/v1/transaction_tags_controller.rb app/policies/transaction_tag_policy.rb test/integration/api/v1/transaction_tags_test.rb config/routes.rb
```

Expected: `no offenses detected`.

- [ ] **Step 3: Commit implementation**

Run:

```bash
git add app/services/transaction_tag_updater.rb app/controllers/api/v1/transaction_tags_controller.rb app/policies/transaction_tag_policy.rb config/routes.rb test/integration/api/v1/transaction_tags_test.rb
git commit --no-gpg-sign -m "feat: add transaction tag lifecycle api"
```

- [ ] **Step 4: Merge back to main after verification**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
git status --short --branch
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-ff --no-gpg-sign feature/ezbookkeeping-transaction-tags-lifecycle-api-slice -m "Merge branch 'feature/ezbookkeeping-transaction-tags-lifecycle-api-slice'"
mise exec -- bin/rails test
```

Expected: merged `main` test suite passes.

- [ ] **Step 5: Cleanup worktree and branch**

Run:

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/ezbookkeeping-transaction-tags-lifecycle-api-slice
git branch -d feature/ezbookkeeping-transaction-tags-lifecycle-api-slice
```
