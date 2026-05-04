# ezBookkeeping Accounts Lifecycle API Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add JSON API support for updating, hiding, and soft-deleting accounts, and include the editable account fields in account JSON responses.

**Architecture:** Keep the endpoint REST-shaped like the existing Rails rewrite API. Account updates are direct model updates for editable metadata only; balances remain controlled by transaction/account-creation workflows and are not accepted by update params.

**Tech Stack:** Rails 8.1, Minitest integration tests, Pundit policy scopes, prefixed IDs, discard soft deletion.

---

## File Map

- Modify `app/models/account.rb`: include `display_order`, `icon_key`, `color_hex`, and `comment` in `as_json`.
- Modify `app/controllers/api/v1/accounts_controller.rb`: add `update` and `destroy` actions; permit `hidden` for update.
- Modify `app/policies/account_policy.rb`: authorize update/destroy for owned accounts.
- Modify `config/routes.rb`: include `:update` and `:destroy` for API accounts.
- Modify `test/integration/api/v1/accounts_test.rb`: cover richer JSON, update, invalid update, destroy, and cross-user boundaries.

## Scope

In scope:
- `PATCH/PUT /api/v1/accounts/:id` with editable metadata: `name`, `account_category`, `account_structure`, `icon_key`, `color_hex`, `currency_code`, `comment`, `hidden`.
- `DELETE /api/v1/accounts/:id` soft-deletes the account with `discard!`.
- Account JSON includes all fields needed by edit/list API clients.
- All reads and writes are scoped to the current API token owner.

Out of scope:
- Updating `balance_cents` through account update.
- Reordering accounts.
- Parent/sub-account lifecycle behavior.
- Legacy `.json` route aliases such as `v1/accounts/modify.json`.

## Regression Risks Covered

- Updating account metadata does not change account balance.
- Invalid update params return validation errors and do not persist.
- Another user's account cannot be updated or deleted.
- Deleted accounts are excluded from the existing kept-list endpoint.

---

### Task 1: Add Failing Tests

**Files:**
- Modify: `test/integration/api/v1/accounts_test.rb`

- [ ] **Step 1: Extend list JSON assertions**

In `lists only the token owner's kept accounts`, after existing balance/currency assertions add:

```ruby
assert_equal 1, account_json.fetch("display_order")
assert_equal 1, account_json.fetch("icon_key")
assert_equal "22C55E", account_json.fetch("color_hex")
assert_equal false, account_json.fetch("hidden")
assert_equal "Wallet", account_json.fetch("comment")
```

Update the local `create_account` helper to set `comment: "Wallet"`.

- [ ] **Step 2: Extend create response assertions**

In `creates an account for the token owner`, after name/balance response assertions add:

```ruby
assert_equal "checking_account", account_json.fetch("account_category")
assert_equal "single_account", account_json.fetch("account_structure")
assert_equal 2, account_json.fetch("icon_key")
assert_equal "22C55E", account_json.fetch("color_hex")
assert_equal "USD", account_json.fetch("currency_code")
assert_equal "Main bank", account_json.fetch("comment")
```

- [ ] **Step 3: Add update test**

Add after the create test:

```ruby
test "updates an account for the token owner" do
  user = create(:user)
  account = create_account(user: user, name: "Checking", balance_cents: 12_300)
  raw_token = issue_token(user)

  patch api_v1_account_path(account),
    params: {
      account: {
        name: "Everyday Checking",
        account_category: "savings_account",
        account_structure: "single_account",
        icon_key: "3",
        color_hex: "#f97316",
        currency_code: "eur",
        comment: "Primary account",
        hidden: "true"
      }
    },
    headers: json_headers(raw_token),
    as: :json

  assert_response :success
  account.reload
  assert_equal "Everyday Checking", account.name
  assert_equal "savings_account", account.account_category
  assert_equal "single_account", account.account_structure
  assert_equal 3, account.icon_key
  assert_equal "F97316", account.color_hex
  assert_equal "EUR", account.currency_code
  assert_equal "Primary account", account.comment
  assert_equal true, account.hidden
  assert_equal 12_300, account.balance_cents

  account_json = JSON.parse(response.body).fetch("account")
  assert_equal account.to_param, account_json.fetch("id")
  assert_equal "Everyday Checking", account_json.fetch("name")
  assert_equal "savings_account", account_json.fetch("account_category")
  assert_equal 3, account_json.fetch("icon_key")
  assert_equal "F97316", account_json.fetch("color_hex")
  assert_equal "EUR", account_json.fetch("currency_code")
  assert_equal "Primary account", account_json.fetch("comment")
  assert_equal true, account_json.fetch("hidden")
  assert_equal 12_300, account_json.fetch("balance_cents")
  refute_includes account_json.keys, "user_id"
end
```

- [ ] **Step 4: Add invalid update test**

Add:

```ruby
test "rejects invalid account update params" do
  user = create(:user)
  account = create_account(user: user, name: "Checking", balance_cents: 12_300)
  raw_token = issue_token(user)

  patch api_v1_account_path(account),
    params: {
      account: {
        name: "",
        account_category: "checking_account",
        account_structure: "single_account",
        icon_key: "3",
        color_hex: "F97316",
        currency_code: "USD",
        comment: "Primary account",
        hidden: "false"
      }
    },
    headers: json_headers(raw_token),
    as: :json

  assert_response :unprocessable_content
  assert_equal "Checking", account.reload.name
  assert_match(/Name/i, response.body)
end
```

- [ ] **Step 5: Add cross-user update test**

Add:

```ruby
test "does not update another user's account" do
  user = create(:user)
  other_user = create(:user)
  account = create_account(user: other_user, name: "Other", balance_cents: 50_000)
  raw_token = issue_token(user)

  patch api_v1_account_path(account),
    params: {
      account: {
        name: "Changed",
        account_category: "checking_account",
        account_structure: "single_account",
        icon_key: "3",
        color_hex: "F97316",
        currency_code: "USD",
        comment: "Changed",
        hidden: "true"
      }
    },
    headers: json_headers(raw_token),
    as: :json

  assert_response :not_found
  assert_equal "Other", account.reload.name
  assert_equal false, account.hidden
end
```

- [ ] **Step 6: Add delete test**

Add:

```ruby
test "deletes an account for the token owner" do
  user = create(:user)
  account = create_account(user: user, name: "Checking", balance_cents: 12_300)
  raw_token = issue_token(user)

  delete api_v1_account_path(account), headers: json_headers(raw_token)

  assert_response :no_content
  assert_empty response.body
  assert_predicate account.reload, :discarded?
end
```

- [ ] **Step 7: Add cross-user delete test**

Add:

```ruby
test "does not delete another user's account" do
  user = create(:user)
  other_user = create(:user)
  account = create_account(user: other_user, name: "Other", balance_cents: 50_000)
  raw_token = issue_token(user)

  delete api_v1_account_path(account), headers: json_headers(raw_token)

  assert_response :not_found
  refute_predicate account.reload, :discarded?
end
```

- [ ] **Step 8: Verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb
```

Expected: FAIL because member routes and richer JSON fields are not available yet.

---

### Task 2: Wire Routes, Policy, Model JSON, And Controller

**Files:**
- Modify: `app/models/account.rb`
- Modify: `config/routes.rb`
- Modify: `app/policies/account_policy.rb`
- Modify: `app/controllers/api/v1/accounts_controller.rb`

- [ ] **Step 1: Extend account JSON**

In `app/models/account.rb`, add these keys to `as_json`:

```ruby
display_order: display_order,
icon_key: icon_key,
color_hex: color_hex,
comment: comment,
```

Keep `user_id` excluded.

- [ ] **Step 2: Add routes**

Change in `config/routes.rb`:

```ruby
resources :accounts, only: [ :index, :create ]
```

to:

```ruby
resources :accounts, only: [ :index, :create, :update, :destroy ]
```

- [ ] **Step 3: Add policy authorization**

In `app/policies/account_policy.rb`, add owned-record checks:

```ruby
def update? = owns_record?
def destroy? = owns_record?

private

def owns_record? = user.present? && record.user_id == user.id
```

- [ ] **Step 4: Add controller actions and update params**

In `app/controllers/api/v1/accounts_controller.rb`, add after `create`:

```ruby
# PATCH/PUT /api/v1/accounts/:id
def update
  account = scoped_account
  authorize account

  if account.update(account_update_params)
    render json: { account: account }
  else
    render json: { errors: account.errors.full_messages }, status: :unprocessable_content
  end
end

# DELETE /api/v1/accounts/:id
def destroy
  account = scoped_account
  authorize account
  account.discard!

  head :no_content
end
```

Add these private methods:

```ruby
def account_update_params
  params.expect(account: [
    :name,
    :account_category,
    :account_structure,
    :icon_key,
    :color_hex,
    :currency_code,
    :comment,
    :hidden
  ])
end

def scoped_account
  policy_scope(Account).kept.find(params[:id])
end
```

Do not permit `balance_cents` or `opening_balance_cents` in `account_update_params`.

- [ ] **Step 5: Run focused tests**

Run:

```bash
mise exec -- bin/rails test test/integration/api/v1/accounts_test.rb
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
mise exec -- bin/rubocop app/models/account.rb app/controllers/api/v1/accounts_controller.rb app/policies/account_policy.rb test/integration/api/v1/accounts_test.rb config/routes.rb
```

Expected: `no offenses detected`.

- [ ] **Step 3: Commit implementation**

Run:

```bash
git add app/models/account.rb app/controllers/api/v1/accounts_controller.rb app/policies/account_policy.rb config/routes.rb test/integration/api/v1/accounts_test.rb
git commit --no-gpg-sign -m "feat: add account lifecycle api"
```

- [ ] **Step 4: Merge back to main after verification**

From `/Users/Jalen/code/jot.jalenx.me`:

```bash
git status --short --branch
GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' git pull --ff-only
git merge --no-ff --no-gpg-sign feature/ezbookkeeping-accounts-lifecycle-api-slice -m "Merge branch 'feature/ezbookkeeping-accounts-lifecycle-api-slice'"
mise exec -- bin/rails test
```

If `git pull --ff-only` fails because the remote SSH endpoint is unavailable, keep the failure in the final report, merge locally from the verified local `main`, and run the same post-merge verification.

- [ ] **Step 5: Cleanup worktree and branch**

Run:

```bash
git worktree remove /Users/Jalen/.config/superpowers/worktrees/jot.jalenx.me/ezbookkeeping-accounts-lifecycle-api-slice
git branch -d feature/ezbookkeeping-accounts-lifecycle-api-slice
```
