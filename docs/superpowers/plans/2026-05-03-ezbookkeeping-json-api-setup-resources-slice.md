# ezBookkeeping JSON API Setup Resources Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add token-authenticated JSON endpoints for creating accounts and for listing/creating transaction tag groups and tags.

**Architecture:** Extend the existing Rails-native `api/v1` boundary with setup resources needed before API clients can create transactions. Controllers stay thin, use `ApiToken` authentication from `ApiController`, authorize with Pundit, scope all user-owned IDs through `current_user`, and return explicit top-level response keys. Account creation delegates to `AccountCreator` so opening-balance transactions and balance rules stay centralized.

**Tech Stack:** Rails 8.1, Pundit, ApiToken bearer auth, existing `AccountCreator`, `TransactionTagGroup`, `TransactionTag`, Minitest integration tests.

---

## File Structure

- Modify `config/routes.rb`: allow `create` for API accounts and add API tag group/tag resources.
- Modify `app/controllers/api/v1/accounts_controller.rb`: add `create` through `AccountCreator`.
- Create `app/controllers/api/v1/transaction_tag_groups_controller.rb`: `index` and `create` for token-owned tag groups.
- Create `app/controllers/api/v1/transaction_tags_controller.rb`: `index` and `create` for token-owned tags.
- Modify `app/models/transaction_tag_group.rb`: add API-safe `as_json` with prefixed id and no `user_id`.
- Modify `app/models/transaction_tag.rb`: add API-safe `as_json` with prefixed id/group id and no `user_id`.
- Modify `app/policies/transaction_tag_policy.rb`: add `index?` for API list authorization.
- Modify `test/integration/api/v1/accounts_test.rb`: account create success and invalid input failure.
- Create `test/integration/api/v1/transaction_tag_groups_test.rb`: list/create/scoping coverage.
- Create `test/integration/api/v1/transaction_tags_test.rb`: list/create/scoping coverage.

---

### Task 1: Add `POST /api/v1/accounts`

**Files:**
- Modify: `test/integration/api/v1/accounts_test.rb`
- Modify: `app/controllers/api/v1/accounts_controller.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing account create API tests**

Add tests proving a bearer token can create an account using JSON params, receives `201` plus `{ account: ... }`, an opening-balance transaction is created through `AccountCreator`, and invalid input returns `422` without creating an account.

Use HTTP-like string params:

```ruby
post api_v1_accounts_path,
  params: {
    account: {
      name: "Checking",
      account_category: "checking_account",
      account_structure: "single_account",
      icon_key: "2",
      color_hex: "#22c55e",
      currency_code: "usd",
      opening_balance_cents: "12300",
      comment: "Main bank"
    }
  },
  headers: json_headers(raw_token),
  as: :json
```

Assert the response is `:created`, the account belongs to the token owner, `balance_cents` is `12300`, color/currency normalization happened, one balance-adjustment transaction was created for that user/account, the response has top-level key `account`, and the JSON does not include `user_id`.

For invalid input, send a blank name with otherwise valid params, assert `:unprocessable_content`, assert no account was created for the user, and assert the response body mentions `Name`.

- [ ] **Step 2: Run account API tests RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb`

Expected: FAIL because POST is not routed or controller action is missing.

- [ ] **Step 3: Implement account create**

Update `config/routes.rb`:

```ruby
resources :accounts, only: [ :index, :create ]
```

Add `create` and private params to `app/controllers/api/v1/accounts_controller.rb`:

```ruby
# POST /api/v1/accounts
def create
  authorize Account
  result = AccountCreator.new.create_account(
    user: current_user,
    attributes: account_attributes,
    opening_balance_cents: opening_balance_cents
  )

  if result.created?
    render json: { account: result.account.as_json }, status: :created
  else
    render json: { errors: result.account.errors.full_messages }, status: :unprocessable_content
  end
end

private

def account_attributes
  account_params.except(:opening_balance_cents).merge(display_order: next_display_order)
end

def account_params
  @account_params ||= params.expect(account: [
    :name,
    :account_category,
    :account_structure,
    :icon_key,
    :color_hex,
    :currency_code,
    :opening_balance_cents,
    :comment
  ])
end

def opening_balance_cents
  account_params[:opening_balance_cents].to_i
end

def next_display_order
  current_user.accounts.kept.where(parent_account_id: nil).maximum(:display_order).to_i + 1
end
```

- [ ] **Step 4: Run account API tests GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit account create endpoint**

```bash
git add config/routes.rb app/controllers/api/v1/accounts_controller.rb test/integration/api/v1/accounts_test.rb
git commit --no-gpg-sign -m "feat: add account create api"
```

---

### Task 2: Add API tag group and tag list/create endpoints

**Files:**
- Create: `test/integration/api/v1/transaction_tag_groups_test.rb`
- Create: `test/integration/api/v1/transaction_tags_test.rb`
- Create: `app/controllers/api/v1/transaction_tag_groups_controller.rb`
- Create: `app/controllers/api/v1/transaction_tags_controller.rb`
- Modify: `app/models/transaction_tag_group.rb`
- Modify: `app/models/transaction_tag.rb`
- Modify: `app/policies/transaction_tag_policy.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing tag group API tests**

Create `test/integration/api/v1/transaction_tag_groups_test.rb` with tests for:

- `GET /api/v1/transaction_tag_groups` lists only the token owner's kept groups, ordered by `display_order, name`, with top-level key `transaction_tag_groups` and no `user_id`.
- `POST /api/v1/transaction_tag_groups` creates a group for the token owner, assigns next `display_order`, returns `201` and `{ transaction_tag_group: ... }`.

Use the same `issue_token` and `json_headers` helpers as existing API tests. Use decoy data for another user and a discarded group.

- [ ] **Step 2: Write failing tag API tests**

Create `test/integration/api/v1/transaction_tags_test.rb` with tests for:

- `GET /api/v1/transaction_tags` lists only the token owner's kept tags, ordered by `display_order, name`, with top-level key `transaction_tags`, prefixed `transaction_tag_group_id`, `hidden`, and no `user_id`.
- `POST /api/v1/transaction_tags` creates a tag for the token owner under a token-owned group, assigns next `display_order`, returns `201` and `{ transaction_tag: ... }`.
- `POST /api/v1/transaction_tags` rejects another user's tag group id with `422`, does not create the tag, and returns an error matching `Transaction tag group is unavailable`.

Use JSON params:

```ruby
post api_v1_transaction_tags_path,
  params: {
    transaction_tag: {
      name: "Meals",
      transaction_tag_group_id: group.to_param
    }
  },
  headers: json_headers(raw_token),
  as: :json
```

- [ ] **Step 3: Run tag API tests RED**

Run: `mise exec -- bin/rails test test/integration/api/v1/transaction_tag_groups_test.rb test/integration/api/v1/transaction_tags_test.rb`

Expected: FAIL because routes/controllers/model JSON are missing.

- [ ] **Step 4: Implement tag group API**

Update `config/routes.rb` inside `api/v1`:

```ruby
resources :transaction_tag_groups, only: [ :index, :create ]
resources :transaction_tags, only: [ :index, :create ]
```

Add `TransactionTagGroup#as_json`:

```ruby
def as_json(_options = {})
  {
    id: to_param,
    name: name,
    display_order: display_order
  }
end
```

Create `app/controllers/api/v1/transaction_tag_groups_controller.rb`:

```ruby
class Api::V1::TransactionTagGroupsController < ApiController
  # GET /api/v1/transaction_tag_groups
  def index
    authorize TransactionTagGroup
    tag_groups = policy_scope(TransactionTagGroup).kept.order(:display_order, :name)

    render json: { transaction_tag_groups: tag_groups.map(&:as_json) }
  end

  # POST /api/v1/transaction_tag_groups
  def create
    authorize TransactionTagGroup
    tag_group = current_user.transaction_tag_groups.build(tag_group_params.merge(display_order: next_display_order))

    if tag_group.save
      render json: { transaction_tag_group: tag_group.as_json }, status: :created
    else
      render json: { errors: tag_group.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def tag_group_params
    params.expect(transaction_tag_group: [ :name ])
  end

  def next_display_order
    current_user.transaction_tag_groups.kept.maximum(:display_order).to_i + 1
  end
end
```

- [ ] **Step 5: Implement tag API**

Add `index?` to `TransactionTagPolicy`:

```ruby
def index? = user.present?
```

Add `TransactionTag#as_json`:

```ruby
def as_json(_options = {})
  {
    id: to_param,
    name: name,
    transaction_tag_group_id: transaction_tag_group&.to_param,
    display_order: display_order,
    hidden: hidden
  }
end
```

Create `app/controllers/api/v1/transaction_tags_controller.rb`:

```ruby
class Api::V1::TransactionTagsController < ApiController
  # GET /api/v1/transaction_tags
  def index
    authorize TransactionTag
    tags = policy_scope(TransactionTag).kept.order(:display_order, :name)

    render json: { transaction_tags: tags.map(&:as_json) }
  end

  # POST /api/v1/transaction_tags
  def create
    authorize TransactionTag
    tag = current_user.transaction_tags.build(tag_params.except(:transaction_tag_group_id))
    tag.transaction_tag_group = tag_group_for(tag)
    tag.display_order = next_display_order

    if tag.errors.empty? && tag.save
      render json: { transaction_tag: tag.as_json }, status: :created
    else
      render json: { errors: tag.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def tag_params
    @tag_params ||= params.expect(transaction_tag: [ :name, :transaction_tag_group_id ])
  end

  def tag_group_for(tag)
    tag_group_id = tag_params[:transaction_tag_group_id]
    return if tag_group_id.blank?

    current_user.transaction_tag_groups.kept.find(TransactionTagGroup.decode_prefix_id(tag_group_id) || tag_group_id)
  rescue ActiveRecord::RecordNotFound
    tag.errors.add(:transaction_tag_group, "is unavailable")
    nil
  end

  def next_display_order
    current_user.transaction_tags.kept.maximum(:display_order).to_i + 1
  end
end
```

- [ ] **Step 6: Run tag API tests GREEN**

Run: `mise exec -- bin/rails test test/integration/api/v1/transaction_tag_groups_test.rb test/integration/api/v1/transaction_tags_test.rb`

Expected: PASS.

- [ ] **Step 7: Commit tag API endpoints**

```bash
git add config/routes.rb app/controllers/api/v1/transaction_tag_groups_controller.rb app/controllers/api/v1/transaction_tags_controller.rb app/models/transaction_tag_group.rb app/models/transaction_tag.rb app/policies/transaction_tag_policy.rb test/integration/api/v1/transaction_tag_groups_test.rb test/integration/api/v1/transaction_tags_test.rb
git commit --no-gpg-sign -m "feat: add transaction tag setup api"
```

---

### Task 3: Verify JSON API setup resources slice

- [ ] **Step 1: Run focused API tests**

Run: `mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb test/integration/api/v1/transaction_tag_groups_test.rb test/integration/api/v1/transaction_tags_test.rb test/integration/api/v1/transaction_categories_test.rb test/integration/api/v1/transactions_test.rb test/integration/api/authentication_test.rb test/integration/api/content_negotiation_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run lint for touched files**

Run: `mise exec -- bin/rubocop app/controllers/api/v1/accounts_controller.rb app/controllers/api/v1/transaction_tag_groups_controller.rb app/controllers/api/v1/transaction_tags_controller.rb app/models/transaction_tag_group.rb app/models/transaction_tag.rb app/policies/transaction_tag_policy.rb test/integration/api/v1/accounts_test.rb test/integration/api/v1/transaction_tag_groups_test.rb test/integration/api/v1/transaction_tags_test.rb config/routes.rb`

Expected: PASS.

- [ ] **Step 4: Check git status**

Run: `git status --short`

Expected: clean working tree.

---

## Self-Review

- Spec coverage: extends the Phase 8 JSON API seam with setup resources needed by service clients before transaction creation: accounts, tag groups, and tags. It uses existing API token auth, content negotiation, top-level response keys, Pundit authorization, and current-user scoping.
- Scope control: does not implement legacy ezBookkeeping `.json` paths, update/delete/batch endpoints, pagination, pictures, geo location, account sub-account creation, tag hidden updates, or MCP adapters.
- Placeholder scan: no TODO/TBD placeholders remain.
- Type consistency: route helpers, controller names, JSON keys, and params consistently use `account`, `transaction_tag_group`, and `transaction_tag`.
