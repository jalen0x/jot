# ezBookkeeping JSON API Transaction Template Update/Delete Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add token-authenticated JSON API endpoints to update and soft-delete transaction templates.

**Architecture:** Keep API behavior consistent with existing resource endpoints: route under `api/v1`, Pundit policy + owner scope, 422 for invalid owned-record references, and `discard!` for deletion. A dedicated updater service owns reassignment of owned records, tag replacement, and template business validations; it does not change display order.

**Tech Stack:** Rails 8.1, Pundit, Discard, Minitest integration tests, prefixed IDs.

---

## File Structure

- Modify `test/integration/api/v1/transaction_templates_test.rb`: add update/delete tests.
- Modify `config/routes.rb`: include `:update` and `:destroy` for API transaction templates.
- Modify `app/policies/transaction_template_policy.rb`: add update/destroy authorization.
- Create `app/services/transaction_template_updater.rb`: update scalar fields, owned associations, and tags in one transaction.
- Modify `app/controllers/api/v1/transaction_templates_controller.rb`: add `update` and `destroy` actions.

---

### Task 1: Add failing API tests

**Files:**
- Modify: `test/integration/api/v1/transaction_templates_test.rb`

- [ ] **Step 1: Write failing tests**

Add tests covering these risks:

1. `PATCH /api/v1/transaction_templates/:id` updates an owned template, changes schedule fields, and replaces tags.
2. Updating with another user's account/category/tag returns 422 and leaves the template unchanged.
3. `DELETE /api/v1/transaction_templates/:id` soft-deletes an owned template and removes it from index responses.
4. Deleting another user's template through owner-scoped lookup returns not found and does not discard it.

- [ ] **Step 2: Run tests RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/transaction_templates_test.rb`

Expected: FAIL because update/destroy routes and actions do not exist.

---

### Task 2: Add route and authorization

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/policies/transaction_template_policy.rb`

- [ ] **Step 1: Expand route**

Change API routes to:

```ruby
resources :transaction_templates, only: [ :index, :create, :update, :destroy ]
```

- [ ] **Step 2: Expand policy**

Add:

```ruby
def update? = user.present? && record.user_id == user.id
def destroy? = user.present? && record.user_id == user.id
```

---

### Task 3: Add updater service and controller actions

**Files:**
- Create: `app/services/transaction_template_updater.rb`
- Modify: `app/controllers/api/v1/transaction_templates_controller.rb`

- [ ] **Step 1: Add `TransactionTemplateUpdater`**

Create a service with `update_template(template:, attributes:, tag_ids:)` that:

- Assigns scalar template fields from params, excluding `display_order` and `last_generated_on`.
- Resolves `account_id`, `destination_account_id`, and `transaction_category_id` through the template user's kept records.
- Resolves tag IDs through the template user's kept tags.
- Reuses the same category/schedule validation rules as creation.
- Saves the template and replaces taggings in one DB transaction.
- Returns `Result` with `updated?` and `template`.

- [ ] **Step 2: Add controller actions**

Add:

```ruby
def update
  template = scoped_template
  authorize template
  result = TransactionTemplateUpdater.new.update_template(
    template: template,
    attributes: transaction_template_params,
    tag_ids: transaction_tag_ids
  )

  if result.updated?
    render json: { transaction_template: result.template.as_json }
  else
    render json: { errors: result.template.errors.full_messages }, status: :unprocessable_content
  end
end

def destroy
  template = scoped_template
  authorize template
  template.discard!
  head :no_content
end

def scoped_template
  policy_scope(TransactionTemplate).kept.find(params[:id])
end
```

- [ ] **Step 3: Run API tests GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/transaction_templates_test.rb`

Expected: PASS.

---

### Task 4: Verify and commit the slice

**Files:**
- All files changed above.

- [ ] **Step 1: Run focused tests**

Run: `mise exec -- bin/rails test test/integration/api/v1/transaction_templates_test.rb test/integration/api/v1/transactions_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run RuboCop for touched files**

Run: `mise exec -- bin/rubocop app/controllers/api/v1/transaction_templates_controller.rb app/policies/transaction_template_policy.rb app/services/transaction_template_updater.rb test/integration/api/v1/transaction_templates_test.rb config/routes.rb`

Expected: PASS.

- [ ] **Step 4: Commit implementation**

Run:

```bash
git add app/controllers/api/v1/transaction_templates_controller.rb app/policies/transaction_template_policy.rb app/services/transaction_template_updater.rb test/integration/api/v1/transaction_templates_test.rb config/routes.rb
git commit --no-gpg-sign -m "feat: update and delete transaction templates api"
```

Expected: commit succeeds and working tree is clean.

---

## Self-Review

- Spec coverage: extends transaction template API beyond index/create to update/delete.
- Scope control: no batch endpoints, HTML UI, legacy compatibility, or hard delete.
- Placeholder scan: no TODO/TBD placeholders remain.
- Testing fit: integration tests cover HTTP boundary, ownership, soft-delete behavior, and invalid owned-record references.
