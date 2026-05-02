# ezBookkeeping Data Clearing Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Phase 3 `LedgerClearance` slice so a signed-in user can clear either transactions only or all current ledger setup/data.

**Architecture:** Keep destructive ledger deletion in a small service object. The controller validates the HTTP/password boundary, scopes all work to `current_user`, and renders one confirmation page with two explicit forms. Clearing uses Rails soft delete (`discarded_at`) for soft-deletable ledger records and deletes join rows first so foreign keys remain valid.

**Tech Stack:** Rails 8.1, Devise, Pundit, Minitest, FactoryBot, PostgreSQL, discard gem, Flowbite semantic Tailwind classes.

---

## File Structure

- Create `app/services/ledger_clearance.rb`: service methods `clear_transactions(user:)` and `clear_all_data(user:)`.
- Create `app/controllers/ledger_clearances_controller.rb`: authenticated `new` and `create` actions.
- Create `app/policies/ledger_clearance_policy.rb`: Pundit policy for the non-AR resource.
- Create `app/views/ledger_clearances/new.html.erb`: confirmation UI with current counts and two password-protected forms.
- Modify `config/routes.rb`: add `resource :ledger_clearance, only: [:new, :create]`.
- Modify `app/views/layouts/application.html.erb`: add a signed-in nav link to the danger-zone page.
- Create `test/services/ledger_clearance_test.rb`: service coverage for scoping, balance reset, and all-data clearing.
- Create `test/integration/ledger_clearances_test.rb`: auth/password/form boundary coverage.

---

### Task 1: Add LedgerClearance service

**Files:**
- Create: `test/services/ledger_clearance_test.rb`
- Create: `app/services/ledger_clearance.rb`

- [ ] **Step 1: Write the failing service tests**

Create `test/services/ledger_clearance_test.rb`:

```ruby
require "test_helper"

class LedgerClearanceTest < ActiveSupport::TestCase
  test "clears current user's transactions and resets account balances" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Cash", balance_cents: 4_500)
    other_account = create_account(user: other_user, name: "Other Cash", balance_cents: 7_000)
    category = create_category(user: user, category_type: :expense)
    tag_group = create_tag_group(user: user)
    tag = create_tag(user: user, tag_group: tag_group)
    transaction = create_transaction(user: user, account: account, category: category)
    create_tagging(user: user, transaction: transaction, tag: tag)
    other_transaction = create_transaction(user: other_user, account: other_account, category: create_category(user: other_user, category_type: :expense))

    LedgerClearance.new.clear_transactions(user: user)

    assert_predicate transaction.reload, :discarded?
    assert_equal 0, account.reload.balance_cents
    assert_equal 0, TransactionTagging.where(user: user).count
    assert_predicate category.reload, :kept?
    assert_predicate tag.reload, :kept?
    assert_predicate tag_group.reload, :kept?
    assert_predicate other_transaction.reload, :kept?
    assert_equal 7_000, other_account.reload.balance_cents
  end

  test "clears all current user's ledger data without touching another user" do
    user = create(:user)
    other_user = create(:user)
    parent_account = create_account(user: user, name: "Parent", account_structure: :multi_sub_accounts)
    account = create_account(user: user, name: "Cash", balance_cents: 4_500, parent_account: parent_account)
    other_account = create_account(user: other_user, name: "Other Cash", balance_cents: 7_000)
    parent_category = create_category(user: user, name: "Bills", category_type: :expense)
    category = create_category(user: user, name: "Utilities", category_type: :expense, parent_category: parent_category)
    tag_group = create_tag_group(user: user)
    tag = create_tag(user: user, tag_group: tag_group)
    transaction = create_transaction(user: user, account: account, category: category)
    create_tagging(user: user, transaction: transaction, tag: tag)
    other_category = create_category(user: other_user, category_type: :expense)
    other_transaction = create_transaction(user: other_user, account: other_account, category: other_category)

    LedgerClearance.new.clear_all_data(user: user)

    assert_equal 0, TransactionTagging.where(user: user).count
    assert_predicate transaction.reload, :discarded?
    assert_predicate account.reload, :discarded?
    assert_predicate parent_account.reload, :discarded?
    assert_equal 0, account.balance_cents
    assert_predicate category.reload, :discarded?
    assert_predicate parent_category.reload, :discarded?
    assert_predicate tag.reload, :discarded?
    assert_predicate tag_group.reload, :discarded?
    assert_predicate other_transaction.reload, :kept?
    assert_predicate other_account.reload, :kept?
    assert_predicate other_category.reload, :kept?
  end

  private

  def create_account(user:, name:, balance_cents: 0, account_structure: :single_account, parent_account: nil)
    Account.create!(
      user: user,
      parent_account: parent_account,
      name: name,
      account_category: :cash,
      account_structure: account_structure,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: balance_cents,
      display_order: 1
    )
  end

  def create_category(user:, category_type:, name: category_type.to_s.humanize, parent_category: nil)
    TransactionCategory.create!(
      user: user,
      parent_category: parent_category,
      name: name,
      category_type: category_type,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end

  def create_tag_group(user:)
    TransactionTagGroup.create!(user: user, name: "Project", display_order: 1)
  end

  def create_tag(user:, tag_group:)
    TransactionTag.create!(user: user, transaction_tag_group: tag_group, name: "Client", display_order: 1)
  end

  def create_transaction(user:, account:, category:)
    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1_200,
      destination_amount_cents: 0,
      comment: "Clear me"
    )
  end

  def create_tagging(user:, transaction:, tag:)
    TransactionTagging.create!(user: user, ledger_transaction: transaction, transaction_tag: tag)
  end
end
```

- [ ] **Step 2: Run service tests to verify RED**

Run: `mise exec -- bin/rails test test/services/ledger_clearance_test.rb`

Expected: FAIL with `uninitialized constant LedgerClearance`.

- [ ] **Step 3: Implement the minimal service**

Create `app/services/ledger_clearance.rb`:

```ruby
class LedgerClearance
  def clear_transactions(user:)
    ActiveRecord::Base.transaction do
      TransactionTagging.where(user: user).delete_all
      user.transactions.kept.update_all(discarded_at: Time.current, updated_at: Time.current)
      user.accounts.kept.update_all(balance_cents: 0, updated_at: Time.current)
    end
  end

  def clear_all_data(user:)
    ActiveRecord::Base.transaction do
      clear_transactions(user: user)
      user.transaction_categories.kept.update_all(discarded_at: Time.current, updated_at: Time.current)
      user.transaction_tags.kept.update_all(discarded_at: Time.current, updated_at: Time.current)
      user.transaction_tag_groups.kept.update_all(discarded_at: Time.current, updated_at: Time.current)
      user.accounts.kept.update_all(discarded_at: Time.current, updated_at: Time.current)
    end
  end
end
```

- [ ] **Step 4: Run service tests to verify GREEN**

Run: `mise exec -- bin/rails test test/services/ledger_clearance_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit service slice**

```bash
git add app/services/ledger_clearance.rb test/services/ledger_clearance_test.rb
git commit -m "feat: clear ledger data"
```

---

### Task 2: Add LedgerClearance HTTP/UI boundary

**Files:**
- Create: `test/integration/ledger_clearances_test.rb`
- Create: `app/policies/ledger_clearance_policy.rb`
- Create: `app/controllers/ledger_clearances_controller.rb`
- Create: `app/views/ledger_clearances/new.html.erb`
- Modify: `config/routes.rb`
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Write failing integration tests**

Create `test/integration/ledger_clearances_test.rb`:

```ruby
require "test_helper"

class LedgerClearancesTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get new_ledger_clearance_path

    assert_redirected_to new_user_session_path
  end

  test "rejects an incorrect password" do
    user = create(:user, password: "password123")
    account = create_account(user: user, balance_cents: 2_000)
    transaction = create_transaction(user: user, account: account)
    sign_in user

    post ledger_clearance_path, params: {
      ledger_clearance: {
        clearance_scope: "transactions",
        current_password: "wrong-password"
      }
    }

    assert_response :unprocessable_content
    assert_match(/password/i, response.body)
    assert_predicate transaction.reload, :kept?
    assert_equal 2_000, account.reload.balance_cents
  end

  test "clears transactions from the confirmation form" do
    user = create(:user, password: "password123")
    account = create_account(user: user, balance_cents: 2_000)
    category = create_category(user: user)
    transaction = create_transaction(user: user, account: account, category: category)
    sign_in user

    post ledger_clearance_path, params: {
      ledger_clearance: {
        clearance_scope: "transactions",
        current_password: "password123"
      }
    }

    assert_redirected_to new_ledger_clearance_path
    follow_redirect!
    assert_match(/Transactions cleared/i, response.body)
    assert_predicate transaction.reload, :discarded?
    assert_equal 0, account.reload.balance_cents
    assert_predicate category.reload, :kept?
  end

  test "clears all data from the confirmation form" do
    user = create(:user, password: "password123")
    account = create_account(user: user, balance_cents: 2_000)
    category = create_category(user: user)
    transaction = create_transaction(user: user, account: account, category: category)
    sign_in user

    post ledger_clearance_path, params: {
      ledger_clearance: {
        clearance_scope: "all",
        current_password: "password123"
      }
    }

    assert_redirected_to new_ledger_clearance_path
    follow_redirect!
    assert_match(/Ledger data cleared/i, response.body)
    assert_predicate transaction.reload, :discarded?
    assert_predicate account.reload, :discarded?
    assert_predicate category.reload, :discarded?
  end

  private

  def create_account(user:, balance_cents: 0)
    Account.create!(
      user: user,
      name: "Cash",
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: balance_cents,
      display_order: 1
    )
  end

  def create_category(user:)
    TransactionCategory.create!(
      user: user,
      name: "Food",
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end

  def create_transaction(user:, account:, category: create_category(user: user))
    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1_200,
      destination_amount_cents: 0,
      comment: "Clear from controller"
    )
  end
end
```

- [ ] **Step 2: Run integration tests to verify RED**

Run: `mise exec -- bin/rails test test/integration/ledger_clearances_test.rb`

Expected: FAIL with missing route helper such as `undefined local variable or method 'new_ledger_clearance_path'`.

- [ ] **Step 3: Add policy, controller, route, nav, and view**

Create `app/policies/ledger_clearance_policy.rb`:

```ruby
class LedgerClearancePolicy < ApplicationPolicy
  def new? = user.present?
  def create? = user.present?
end
```

Create `app/controllers/ledger_clearances_controller.rb`:

```ruby
class LedgerClearancesController < ApplicationController
  before_action :authenticate_user!

  # GET /ledger_clearance/new
  def new
    authorize :ledger_clearance
    load_counts
  end

  # POST /ledger_clearance
  def create
    authorize :ledger_clearance
    permitted = ledger_clearance_params

    unless current_user.valid_password?(permitted[:current_password])
      @ledger_clearance_error = "Current password is incorrect."
      load_counts
      render :new, status: :unprocessable_content
      return
    end

    case permitted[:clearance_scope]
    when "transactions"
      LedgerClearance.new.clear_transactions(user: current_user)
      redirect_to new_ledger_clearance_path, notice: "Transactions cleared."
    when "all"
      LedgerClearance.new.clear_all_data(user: current_user)
      redirect_to new_ledger_clearance_path, notice: "Ledger data cleared."
    else
      @ledger_clearance_error = "Choose what to clear."
      load_counts
      render :new, status: :unprocessable_content
    end
  end

  private

  def ledger_clearance_params
    params.expect(ledger_clearance: [ :clearance_scope, :current_password ])
  end

  def load_counts
    @ledger_counts = {
      accounts: current_user.accounts.kept.count,
      transaction_categories: current_user.transaction_categories.kept.count,
      transaction_tags: current_user.transaction_tags.kept.count,
      transactions: current_user.transactions.kept.count
    }
  end
end
```

Add to `config/routes.rb` near the other singleton resources:

```ruby
resource :ledger_clearance, only: [ :new, :create ]
```

Add a signed-in navigation link in `app/views/layouts/application.html.erb` near data/ledger links:

```erb
<%= link_to "Clear Data", new_ledger_clearance_path, class: "text-sm font-medium text-body hover:text-heading" %>
```

Create `app/views/ledger_clearances/new.html.erb`:

```erb
<% content_for :title, "Clear Ledger Data" %>

<section class="space-y-8">
  <div class="max-w-3xl space-y-3">
    <p class="text-sm font-medium uppercase tracking-wide text-fg-brand">Data management</p>
    <h1 class="text-3xl font-semibold tracking-tight text-heading">Clear ledger data</h1>
    <p class="text-body">Remove your transaction history or clear the full ledger setup. This cannot be undone.</p>
  </div>

  <div class="grid gap-4 md:grid-cols-4">
    <div class="bg-neutral-primary-soft border border-default rounded-base shadow-xs p-4">
      <p class="text-sm text-body-subtle">Accounts</p>
      <p class="mt-2 text-2xl font-semibold text-heading"><%= @ledger_counts[:accounts] %></p>
    </div>
    <div class="bg-neutral-primary-soft border border-default rounded-base shadow-xs p-4">
      <p class="text-sm text-body-subtle">Categories</p>
      <p class="mt-2 text-2xl font-semibold text-heading"><%= @ledger_counts[:transaction_categories] %></p>
    </div>
    <div class="bg-neutral-primary-soft border border-default rounded-base shadow-xs p-4">
      <p class="text-sm text-body-subtle">Tags</p>
      <p class="mt-2 text-2xl font-semibold text-heading"><%= @ledger_counts[:transaction_tags] %></p>
    </div>
    <div class="bg-neutral-primary-soft border border-default rounded-base shadow-xs p-4">
      <p class="text-sm text-body-subtle">Transactions</p>
      <p class="mt-2 text-2xl font-semibold text-heading"><%= @ledger_counts[:transactions] %></p>
    </div>
  </div>

  <% if @ledger_clearance_error.present? %>
    <div class="rounded-base border border-danger bg-neutral-primary p-4 text-danger">
      <%= @ledger_clearance_error %>
    </div>
  <% end %>

  <div class="grid gap-6 lg:grid-cols-2">
    <%= form_with url: ledger_clearance_path, scope: :ledger_clearance, class: "bg-neutral-primary-soft border border-default rounded-base shadow-xs p-6 space-y-4" do |form| %>
      <%= form.hidden_field :clearance_scope, value: "transactions" %>
      <div>
        <h2 class="text-xl font-semibold text-heading">Clear all transactions</h2>
        <p class="mt-2 text-sm text-body">Deletes transaction history and resets account balances to zero. Accounts, categories, and tags remain available.</p>
      </div>
      <div>
        <%= form.label :current_password, "Current password", class: "mb-2 block text-sm font-medium text-heading" %>
        <%= form.password_field :current_password, autocomplete: "current-password", class: "bg-neutral-secondary-medium border border-default-medium text-heading text-sm rounded-base focus:ring-brand focus:border-brand block w-full px-3 py-2.5 shadow-xs placeholder:text-body" %>
      </div>
      <%= form.submit "Clear Transactions", class: "text-danger bg-neutral-primary border border-danger hover:bg-danger hover:text-white focus:ring-4 focus:ring-neutral-tertiary font-medium leading-5 rounded-base text-sm px-4 py-2.5 focus:outline-none" %>
    <% end %>

    <%= form_with url: ledger_clearance_path, scope: :ledger_clearance, class: "bg-neutral-primary-soft border border-default rounded-base shadow-xs p-6 space-y-4" do |form| %>
      <%= form.hidden_field :clearance_scope, value: "all" %>
      <div>
        <h2 class="text-xl font-semibold text-heading">Clear all data</h2>
        <p class="mt-2 text-sm text-body">Deletes accounts, categories, tags, and transactions for this user. Other users' ledger data is not affected.</p>
      </div>
      <div>
        <%= form.label :current_password, "Current password", class: "mb-2 block text-sm font-medium text-heading" %>
        <%= form.password_field :current_password, autocomplete: "current-password", class: "bg-neutral-secondary-medium border border-default-medium text-heading text-sm rounded-base focus:ring-brand focus:border-brand block w-full px-3 py-2.5 shadow-xs placeholder:text-body" %>
      </div>
      <%= form.submit "Clear All Data", class: "text-danger bg-neutral-primary border border-danger hover:bg-danger hover:text-white focus:ring-4 focus:ring-neutral-tertiary font-medium leading-5 rounded-base text-sm px-4 py-2.5 focus:outline-none" %>
    <% end %>
  </div>
</section>
```

- [ ] **Step 4: Run integration tests to verify GREEN**

Run: `mise exec -- bin/rails test test/integration/ledger_clearances_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit HTTP/UI slice**

```bash
git add app/controllers/ledger_clearances_controller.rb app/policies/ledger_clearance_policy.rb app/views/ledger_clearances/new.html.erb config/routes.rb app/views/layouts/application.html.erb test/integration/ledger_clearances_test.rb
git commit -m "feat: add ledger clearance UI"
```

---

### Task 3: Verify data-clearing slice

**Files:**
- No source edits expected unless verification reveals failures.

- [ ] **Step 1: Run focused tests**

Run: `mise exec -- bin/rails test test/services/ledger_clearance_test.rb test/integration/ledger_clearances_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run lint for touched Rails/Ruby/ERB files**

Run: `mise exec -- bin/rubocop app/services/ledger_clearance.rb app/controllers/ledger_clearances_controller.rb app/policies/ledger_clearance_policy.rb test/services/ledger_clearance_test.rb test/integration/ledger_clearances_test.rb`

Expected: PASS.

Run: `mise exec -- bundle exec erb_lint app/views/ledger_clearances/new.html.erb app/views/layouts/application.html.erb`

Expected: PASS.

- [ ] **Step 4: Check git status**

Run: `git status --short`

Expected: clean working tree.

---

## Self-Review

- Spec coverage: implements the Phase 3 `LedgerClearance` artifact from the parity map and the destructive-operation route guidance from the rewrite design. It covers transactions-only and all-ledger-data clearing. It does not implement source features outside current Rails artifacts, such as transaction pictures, templates, custom exchange rates, or insights explorers, because those models do not exist yet.
- Placeholder scan: no TODO/TBD placeholders remain.
- Type consistency: the plan consistently uses `LedgerClearance`, `ledger_clearance_path`, `new_ledger_clearance_path`, `clearance_scope`, and `current_password`.
