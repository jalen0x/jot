# ezBookkeeping JSON API Transaction Templates Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add token-authenticated JSON API endpoints to list and create transaction templates, including scheduled template fields and tag associations.

**Architecture:** Follow the existing API pattern under `Api::V1`: token auth and JSON negotiation stay in `ApiController`; controllers authorize with Pundit and scope records to `current_user`; a small service owns template creation, owned-record lookup, tag attachment, and category/schedule business checks. Model `as_json` exposes stable API fields without leaking `user_id`.

**Tech Stack:** Rails 8.1, Pundit, Minitest integration tests, prefixed IDs, Discard soft delete.

---

## File Structure

- Create `test/integration/api/v1/transaction_templates_test.rb`: API tests for owner-scoped listing, creation, and rejecting another user's owned records.
- Modify `config/routes.rb`: add `resources :transaction_templates, only: [:index, :create]` under `api/v1`.
- Create `app/policies/transaction_template_policy.rb`: index/create authorization and owner scope.
- Modify `app/models/transaction_template.rb`: add `as_json` for API responses.
- Create `app/services/transaction_template_creator.rb`: create templates with owned account/category/tag lookup and business validation.
- Create `app/controllers/api/v1/transaction_templates_controller.rb`: index/create endpoints.

---

### Task 1: Add failing API tests

**Files:**
- Create: `test/integration/api/v1/transaction_templates_test.rb`

- [ ] **Step 1: Write failing tests**

Create API tests covering three concrete risks:

1. Index returns only the token owner's kept templates and includes schedule/tag fields.
2. Create persists a scheduled template for the token owner using prefixed account/category/tag IDs.
3. Create rejects another user's account/category/tag so templates cannot cross tenant boundaries.

Use `as: :json` and string params where API clients send strings.

- [ ] **Step 2: Run tests RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/transaction_templates_test.rb`

Expected: FAIL because the route/controller/policy/API JSON do not exist.

---

### Task 2: Add route, policy, JSON representation, and creator service

**Files:**
- Modify: `config/routes.rb`
- Create: `app/policies/transaction_template_policy.rb`
- Modify: `app/models/transaction_template.rb`
- Create: `app/services/transaction_template_creator.rb`

- [ ] **Step 1: Add the API route**

Inside `namespace :api do; namespace :v1 do`, add:

```ruby
resources :transaction_templates, only: [ :index, :create ]
```

- [ ] **Step 2: Add policy**

Create `app/policies/transaction_template_policy.rb`:

```ruby
class TransactionTemplatePolicy < ApplicationPolicy
  def index? = user.present?
  def create? = user.present?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
```

- [ ] **Step 3: Add `TransactionTemplate#as_json`**

Expose only API-safe fields:

```ruby
def as_json(_options = {})
  {
    id: to_param,
    template_kind: template_kind,
    transaction_kind: transaction_kind,
    name: name,
    account_id: account.to_param,
    destination_account_id: destination_account&.to_param,
    transaction_category_id: transaction_category&.to_param,
    source_amount_cents: source_amount_cents,
    destination_amount_cents: destination_amount_cents,
    hide_amount: hide_amount,
    comment: comment,
    schedule_frequency: schedule_frequency,
    schedule_rule: schedule_rule,
    schedule_start_on: schedule_start_on&.iso8601,
    schedule_end_on: schedule_end_on&.iso8601,
    scheduled_at_minutes: scheduled_at_minutes,
    timezone_utc_offset_minutes: timezone_utc_offset_minutes,
    last_generated_on: last_generated_on&.iso8601,
    display_order: display_order,
    hidden: hidden,
    transaction_tag_ids: transaction_tags.map(&:to_param)
  }
end
```

- [ ] **Step 4: Add `TransactionTemplateCreator`**

Create `app/services/transaction_template_creator.rb` with a `create_template(user:, attributes:, tag_ids:)` method. It should:

- Build `current_user.transaction_templates` from scalar attributes.
- Assign only user-owned kept `account`, `destination_account`, and `transaction_category` via prefixed or numeric IDs.
- Attach only user-owned kept tags.
- Set `display_order` to max kept display order for the same `template_kind` + 1.
- Reject mismatched category type unless the template is `balance_adjustment`.
- Reject scheduled templates with blank non-disabled `schedule_rule`, or disabled schedules with a nonblank `schedule_rule`.
- Save template and taggings in one DB transaction.
- Return `Result` with `created?` and `template`.

---

### Task 3: Add API controller

**Files:**
- Create: `app/controllers/api/v1/transaction_templates_controller.rb`

- [ ] **Step 1: Add controller**

Create `Api::V1::TransactionTemplatesController`:

```ruby
class Api::V1::TransactionTemplatesController < ApiController
  def index
    authorize TransactionTemplate
    templates = policy_scope(TransactionTemplate).kept.includes(:transaction_tags).order(:template_kind, :display_order, :name)

    render json: { transaction_templates: templates.map(&:as_json) }
  end

  def create
    authorize TransactionTemplate
    result = TransactionTemplateCreator.new.create_template(
      user: current_user,
      attributes: transaction_template_params,
      tag_ids: transaction_tag_ids
    )

    if result.created?
      render json: { transaction_template: result.template.as_json }, status: :created
    else
      render json: { errors: result.template.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def transaction_template_params
    @transaction_template_params ||= params.expect(transaction_template: [
      :template_kind,
      :transaction_kind,
      :name,
      :account_id,
      :destination_account_id,
      :transaction_category_id,
      :source_amount_cents,
      :destination_amount_cents,
      :hide_amount,
      :comment,
      :schedule_frequency,
      :schedule_rule,
      :schedule_start_on,
      :schedule_end_on,
      :scheduled_at_minutes,
      :timezone_utc_offset_minutes,
      transaction_tag_ids: []
    ])
  end

  def transaction_tag_ids
    Array(transaction_template_params[:transaction_tag_ids]).reject(&:blank?)
  end
end
```

- [ ] **Step 2: Run API tests GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/transaction_templates_test.rb`

Expected: PASS.

---

### Task 4: Verify and commit the slice

**Files:**
- All files changed above.

- [ ] **Step 1: Run focused tests**

Run: `mise exec -- bin/rails test test/integration/api/v1/transaction_templates_test.rb test/services/scheduled_transaction_creator_test.rb test/models/transaction_template_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run RuboCop for touched files**

Run: `mise exec -- bin/rubocop app/controllers/api/v1/transaction_templates_controller.rb app/models/transaction_template.rb app/policies/transaction_template_policy.rb app/services/transaction_template_creator.rb test/integration/api/v1/transaction_templates_test.rb config/routes.rb`

Expected: PASS.

- [ ] **Step 4: Commit implementation**

Run:

```bash
git add app/controllers/api/v1/transaction_templates_controller.rb app/models/transaction_template.rb app/policies/transaction_template_policy.rb app/services/transaction_template_creator.rb test/integration/api/v1/transaction_templates_test.rb config/routes.rb
git commit --no-gpg-sign -m "feat: add transaction templates api"
```

Expected: commit succeeds and working tree is clean.

---

## Self-Review

- Spec coverage: extends Phase 7/8 coverage with transaction template machine interface for index/create.
- Scope control: no UI, update/delete/batch endpoints, or legacy endpoint compatibility in this slice.
- Placeholder scan: no TODO/TBD placeholders remain.
- Test fit: integration tests cover API boundary and tenant isolation; existing service tests continue to cover scheduled execution behavior.
