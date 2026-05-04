# ezBookkeeping Transaction Categories Lifecycle API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add JSON API support for updating, hiding, reparenting, unparenting, and soft-deleting transaction categories.

**Architecture:** Keep the endpoint REST-shaped like the existing Rails rewrite API. Add a focused `TransactionCategoryUpdater` service for owned parent-category assignment and model validation; keep the controller as a thin Pundit-scoped boundary.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit policy scopes, prefixed IDs, discard soft deletion.

---

## File Map

- Create `app/services/transaction_category_updater.rb`: update category attributes and optional parent with ownership validation.
- Modify `app/controllers/api/v1/transaction_categories_controller.rb`: add `update` and `destroy` actions.
- Modify `app/policies/transaction_category_policy.rb`: authorize update/destroy for owned categories.
- Modify `config/routes.rb`: include `:update` and `:destroy` for API transaction categories.
- Modify `test/integration/api/v1/transaction_categories_test.rb`: cover update, unparent, destroy, cross-user update/delete, and another user's parent rejection.

## Scope

In scope:
- `PATCH/PUT /api/v1/transaction_categories/:id` with `transaction_category[name]`, `category_type`, `parent_category_id`, `icon_key`, `color_hex`, `comment`, and `hidden`.
- Empty `parent_category_id` removes the parent category.
- `DELETE /api/v1/transaction_categories/:id` soft-deletes the category with `discard!`.
- All reads and writes are scoped to the current API token owner.

Out of scope:
- Category reordering.
- Recursive delete/hide of subcategories.
- Removing or rewriting historical transactions when a category is deleted.
- Legacy `.json` route aliases such as `v1/transaction/categories/modify.json`.

## Regression Risks Covered

- A category can move to a user-owned parent or become top-level.
- Hidden categories can be updated without leaving the owner scope.
- Another user's category cannot be updated or deleted.
- Another user's parent category cannot be assigned.
- Deleted categories are excluded from the existing kept-list endpoint.

---

### Task 1: Add Failing Tests

**Files:**
- Modify: `test/integration/api/v1/transaction_categories_test.rb`

- [ ] **Step 1: Add update test**

Add after the create test:

```ruby
test "updates a transaction category for the token owner" do
  user = create(:user)
  old_parent = create_category(user: user, name: "Food", category_type: :expense, display_order: 1)
  new_parent = create_category(user: user, name: "Travel", category_type: :expense, display_order: 2)
  category = create_category(user: user, name: "Dining", category_type: :expense, parent_category: old_parent, display_order: 3)
  raw_token = issue_token(user)

  patch api_v1_transaction_category_path(category),
    params: {
      transaction_category: {
        name: "Flights",
        category_type: "expense",
        parent_category_id: new_parent.to_param,
        icon_key: "3",
        color_hex: "#22c55e",
        comment: "Air travel",
        hidden: "true"
      }
    },
    headers: json_headers(raw_token),
    as: :json

  assert_response :success
  category.reload
  assert_equal "Flights", category.name
  assert_equal "expense", category.category_type
  assert_equal new_parent, category.parent_category
  assert_equal 3, category.icon_key
  assert_equal "22C55E", category.color_hex
  assert_equal "Air travel", category.comment
  assert_equal true, category.hidden

  category_json = JSON.parse(response.body).fetch("transaction_category")
  assert_equal category.to_param, category_json.fetch("id")
  assert_equal "Flights", category_json.fetch("name")
  assert_equal new_parent.to_param, category_json.fetch("parent_category_id")
  assert_equal true, category_json.fetch("hidden")
  refute_includes category_json.keys, "user_id"
end
```

- [ ] **Step 2: Add unparent test**

Add:

```ruby
test "unparents a transaction category" do
  user = create(:user)
  parent = create_category(user: user, name: "Food", category_type: :expense, display_order: 1)
  category = create_category(user: user, name: "Dining", category_type: :expense, parent_category: parent, display_order: 2)
  raw_token = issue_token(user)

  patch api_v1_transaction_category_path(category),
    params: {
      transaction_category: {
        name: "Dining",
        category_type: "expense",
        parent_category_id: "",
        icon_key: "1",
        color_hex: "F97316",
        comment: "",
        hidden: "false"
      }
    },
    headers: json_headers(raw_token),
    as: :json

  assert_response :success
  assert_nil category.reload.parent_category
  assert_nil JSON.parse(response.body).fetch("transaction_category").fetch("parent_category_id")
end
```

- [ ] **Step 3: Add unavailable parent test for update**

Add:

```ruby
test "rejects another user's parent category on update" do
  user = create(:user)
  category = create_category(user: user, name: "Dining", category_type: :expense, display_order: 1)
  other_parent = create_category(user: create(:user), name: "Other Food", category_type: :expense, display_order: 1)
  raw_token = issue_token(user)

  patch api_v1_transaction_category_path(category),
    params: {
      transaction_category: {
        name: "Dining",
        category_type: "expense",
        parent_category_id: other_parent.to_param,
        icon_key: "1",
        color_hex: "F97316",
        comment: "Meals",
        hidden: "false"
      }
    },
    headers: json_headers(raw_token),
    as: :json

  assert_response :unprocessable_content
  assert_nil category.reload.parent_category
  assert_match(/Parent category is unavailable/i, response.body)
end
```

- [ ] **Step 4: Add cross-user update test**

Add:

```ruby
test "does not update another user's transaction category" do
  user = create(:user)
  other_user = create(:user)
  category = create_category(user: other_user, name: "Other", category_type: :expense, display_order: 1)
  raw_token = issue_token(user)

  patch api_v1_transaction_category_path(category),
    params: {
      transaction_category: {
        name: "Changed",
        category_type: "expense",
        parent_category_id: "",
        icon_key: "2",
        color_hex: "22C55E",
        comment: "Changed",
        hidden: "true"
      }
    },
    headers: json_headers(raw_token),
    as: :json

  assert_response :not_found
  assert_equal "Other", category.reload.name
  assert_equal false, category.hidden
end
```

- [ ] **Step 5: Add delete test**

Add:

```ruby
test "deletes a transaction category for the token owner" do
  user = create(:user)
  category = create_category(user: user, name: "Dining", category_type: :expense, display_order: 1)
  raw_token = issue_token(user)

  delete api_v1_transaction_category_path(category), headers: json_headers(raw_token)

  assert_response :no_content
  assert_empty response.body
  assert_predicate category.reload, :discarded?
end
```

- [ ] **Step 6: Add cross-user delete test**

Add:

```ruby
test "does not delete another user's transaction category" do
  user = create(:user)
  other_user = create(:user)
  category = create_category(user: other_user, name: "Other", category_type: :expense, display_order: 1)
  raw_token = issue_token(user)

  delete api_v1_transaction_category_path(category), headers: json_headers(raw_token)

  assert_response :not_found
  refute_predicate category.reload, :discarded?
end
```

- [ ] **Step 7: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_categories_test.rb
```

Expected: FAIL because member routes are not available yet.

---

### Task 2: Implement TransactionCategoryUpdater

**Files:**
- Create: `app/services/transaction_category_updater.rb`

- [ ] **Step 1: Create service**

Create `app/services/transaction_category_updater.rb`:

```ruby
class TransactionCategoryUpdater
  def update_category(category:, attributes:)
    attributes = attributes.to_h.symbolize_keys
    category.assign_attributes(category_attributes(attributes))
    category.parent_category = parent_category_for(category, attributes[:parent_category_id])

    return Result.new(updated: false, category: category) if category.errors.any? || !category.valid?

    category.save!
    Result.new(updated: true, category: category)
  end

  private

  def category_attributes(attributes)
    {
      name: attributes[:name],
      category_type: attributes[:category_type],
      icon_key: attributes[:icon_key],
      color_hex: attributes[:color_hex],
      comment: attributes[:comment],
      hidden: ActiveModel::Type::Boolean.new.cast(attributes[:hidden])
    }
  end

  def parent_category_for(category, parent_category_id)
    return if parent_category_id.blank?

    parent_category = category.user.transaction_categories.kept.find(decoded_id(category.user.transaction_categories.kept, parent_category_id))
    return parent_category unless parent_category == category

    category.errors.add(:parent_category, "cannot be itself")
    nil
  rescue ActiveRecord::RecordNotFound
    category.errors.add(:parent_category, "is unavailable")
    nil
  end

  def decoded_id(scope, id)
    scope.klass.decode_prefix_id(id) || id
  end

  class Result
    attr_reader :category

    def initialize(updated:, category:)
      @updated = updated
      @category = category
    end

    def updated? = @updated
  end
end
```

---

### Task 3: Wire Routes, Policy, And Controller

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/policies/transaction_category_policy.rb`
- Modify: `app/controllers/api/v1/transaction_categories_controller.rb`

- [ ] **Step 1: Add routes**

Change in `config/routes.rb`:

```ruby
resources :transaction_categories, only: [ :index, :create ]
```

to:

```ruby
resources :transaction_categories, only: [ :index, :create, :update, :destroy ]
```

- [ ] **Step 2: Add policy authorization**

In `app/policies/transaction_category_policy.rb`, add owned-record checks:

```ruby
def update? = owns_record?
def destroy? = owns_record?

private

def owns_record? = user.present? && record.user_id == user.id
```

- [ ] **Step 3: Add controller actions**

In `app/controllers/api/v1/transaction_categories_controller.rb`, add after `create`:

```ruby
# PATCH/PUT /api/v1/transaction_categories/:id
def update
  category = scoped_category
  authorize category
  result = TransactionCategoryUpdater.new.update_category(category: category, attributes: category_params)

  if result.updated?
    render json: { transaction_category: result.category }
  else
    render json: { errors: result.category.errors.full_messages }, status: :unprocessable_content
  end
end

# DELETE /api/v1/transaction_categories/:id
def destroy
  category = scoped_category
  authorize category
  category.discard!

  head :no_content
end
```

Add this private method:

```ruby
def scoped_category
  policy_scope(TransactionCategory).kept.find(params[:id])
end
```

Update `category_params` from:

```ruby
@category_params ||= params.expect(transaction_category: [ :name, :category_type, :parent_category_id, :icon_key, :color_hex, :comment ])
```

to:

```ruby
@category_params ||= params.expect(transaction_category: [ :name, :category_type, :parent_category_id, :icon_key, :color_hex, :comment, :hidden ])
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/transaction_categories_test.rb
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
mise exec -- bin/rubocop app/services/transaction_category_updater.rb app/controllers/api/v1/transaction_categories_controller.rb app/policies/transaction_category_policy.rb test/integration/api/v1/transaction_categories_test.rb config/routes.rb
```

Expected: `no offenses detected`.

- [ ] **Step 3: Commit implementation**

Run:

```bash
git add app/services/transaction_category_updater.rb app/controllers/api/v1/transaction_categories_controller.rb app/policies/transaction_category_policy.rb config/routes.rb test/integration/api/v1/transaction_categories_test.rb
git commit --no-gpg-sign -m "feat: add transaction category lifecycle api"
```

- [ ] **Step 4: Merge back to main after verification**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
git status --short --branch
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-ff --no-gpg-sign feature/ezbookkeeping-transaction-categories-lifecycle-api-slice -m "Merge branch 'feature/ezbookkeeping-transaction-categories-lifecycle-api-slice'"
mise exec -- bin/rails test
```

Expected: merged `main` test suite passes.

- [ ] **Step 5: Cleanup worktree and branch**

Run:

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/ezbookkeeping-transaction-categories-lifecycle-api-slice
git branch -d feature/ezbookkeeping-transaction-categories-lifecycle-api-slice
```
