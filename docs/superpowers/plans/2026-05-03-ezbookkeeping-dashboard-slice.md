# ezBookkeeping Dashboard Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Rails-native dashboard that summarizes the current user's ledger and links to the primary Phase 1 workflows.

**Architecture:** `DashboardSummary#summarize` owns dashboard read aggregation. `DashboardController#show` authenticates, authorizes a non-AR dashboard resource, loads the summary, and renders a server-side view using existing Flowbite semantic classes.

**Tech Stack:** Rails 8.1, PostgreSQL SQL schema, Devise, Pundit, ViewComponent, Hotwire/Turbo, Flowbite semantic classes, Minitest, FactoryBot.

---

## File Structure

- `app/services/dashboard_summary.rb`: current-user dashboard aggregate.
- `test/services/dashboard_summary_test.rb`: scoped aggregate and recent transaction ordering coverage.
- `app/policies/dashboard_policy.rb`: signed-in-only dashboard authorization.
- `app/controllers/dashboards_controller.rb`: dashboard show boundary.
- `app/views/dashboards/show.html.erb`: SSR dashboard cards and recent transactions.
- `config/routes.rb`: canonical `resource :dashboard` route.
- `app/views/layouts/application.html.erb`: signed-in Dashboard nav link.
- `test/integration/dashboard_test.rb`: auth and scoping coverage.

## Task 1: DashboardSummary Service

**Files:**
- Create: `test/services/dashboard_summary_test.rb`
- Create: `app/services/dashboard_summary.rb`

- [ ] **Step 1: Write failing summary service tests**

Create `test/services/dashboard_summary_test.rb`:

```ruby
require "test_helper"

class DashboardSummaryTest < ActiveSupport::TestCase
  test "summarizes only the current user's kept ledger" do
    user = create(:user)
    other_user = create(:user)
    create_account(user: user, name: "Checking", balance_cents: 5_000)
    discarded_account = create_account(user: user, name: "Closed", balance_cents: 9_999)
    discarded_account.discard!
    create_account(user: other_user, name: "Other", balance_cents: 7_777)
    create_transaction(user: user, comment: "Groceries")
    discarded_transaction = create_transaction(user: user, comment: "Discarded")
    discarded_transaction.discard!
    create_transaction(user: other_user, comment: "Other")

    summary = DashboardSummary.new.summarize(user: user)

    assert_equal 5_000, summary.total_balance_cents
    assert_equal 1, summary.account_count
    assert_equal 1, summary.transaction_count
    assert_equal [ "Groceries" ], summary.recent_transactions.map(&:comment)
  end

  test "returns five most recent transactions newest first" do
    user = create(:user)
    6.times do |index|
      create_transaction(
        user: user,
        comment: "Transaction #{index}",
        transacted_at: Time.zone.parse("2026-05-0#{index + 1} 10:00:00")
      )
    end

    summary = DashboardSummary.new.summarize(user: user)

    assert_equal [ "Transaction 5", "Transaction 4", "Transaction 3", "Transaction 2", "Transaction 1" ], summary.recent_transactions.map(&:comment)
  end

  private

  def create_account(user:, name:, balance_cents:)
    Account.create!(
      user: user,
      name: name,
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: balance_cents,
      display_order: 1
    )
  end

  def create_transaction(user:, comment:, transacted_at: Time.zone.parse("2026-05-03 10:00:00"))
    account = create_account(user: user, name: "Cash #{comment}", balance_cents: 0)
    category = TransactionCategory.create!(
      user: user,
      name: "Food #{comment}",
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: transacted_at,
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1000,
      destination_amount_cents: 0,
      comment: comment
    )
  end
end
```

- [ ] **Step 2: Run summary tests to verify RED**

Run:

```bash
mise exec -- bin/rails test test/services/dashboard_summary_test.rb
```

Expected: FAIL with `uninitialized constant DashboardSummary`.

- [ ] **Step 3: Implement DashboardSummary**

Create `app/services/dashboard_summary.rb`:

```ruby
class DashboardSummary
  def summarize(user:)
    accounts = user.accounts.kept
    transactions = user.transactions.kept

    Result.new(
      total_balance_cents: accounts.sum(:balance_cents),
      account_count: accounts.count,
      transaction_count: transactions.count,
      recent_transactions: transactions.includes(:account, :transaction_category).order(transacted_at: :desc, id: :desc).limit(5).to_a
    )
  end

  class Result
    attr_reader :total_balance_cents, :account_count, :transaction_count, :recent_transactions

    def initialize(total_balance_cents:, account_count:, transaction_count:, recent_transactions:)
      @total_balance_cents = total_balance_cents
      @account_count = account_count
      @transaction_count = transaction_count
      @recent_transactions = recent_transactions
    end
  end
end
```

- [ ] **Step 4: Run summary tests to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/services/dashboard_summary_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit DashboardSummary**

Run:

```bash
git add app/services/dashboard_summary.rb test/services/dashboard_summary_test.rb
git commit -m "feat: summarize dashboard ledger"
```

## Task 2: Dashboard Route And View

**Files:**
- Create: `test/integration/dashboard_test.rb`
- Create: `app/policies/dashboard_policy.rb`
- Create: `app/controllers/dashboards_controller.rb`
- Create: `app/views/dashboards/show.html.erb`
- Modify: `config/routes.rb`
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Write failing dashboard integration tests**

Create `test/integration/dashboard_test.rb`:

```ruby
require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get dashboard_path

    assert_redirected_to new_user_session_path
  end

  test "shows only current user's ledger summary" do
    user = create(:user)
    other_user = create(:user)
    create_account(user: user, name: "Checking", balance_cents: 4_000)
    create_transaction(user: user, comment: "Groceries")
    create_account(user: other_user, name: "Other Checking", balance_cents: 9_999)
    create_transaction(user: other_user, comment: "Other Groceries")

    sign_in user
    get dashboard_path

    assert_response :success
    assert_select "h1", text: /dashboard/i
    assert_select "p", text: /40.00/
    assert_select "li", text: /Groceries/i
    assert_select "li", text: /Other Groceries/i, count: 0
  end

  private

  def create_account(user:, name:, balance_cents:)
    Account.create!(
      user: user,
      name: name,
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: balance_cents,
      display_order: 1
    )
  end

  def create_transaction(user:, comment:)
    account = create_account(user: user, name: "Cash #{comment}", balance_cents: 0)
    category = TransactionCategory.create!(
      user: user,
      name: "Food #{comment}",
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1000,
      destination_amount_cents: 0,
      comment: comment
    )
  end
end
```

- [ ] **Step 2: Run dashboard integration test to verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/dashboard_test.rb
```

Expected: FAIL with missing `dashboard_path`.

- [ ] **Step 3: Add policy, route, and controller**

Create `app/policies/dashboard_policy.rb`:

```ruby
class DashboardPolicy < ApplicationPolicy
  def show? = user.present?
end
```

Add this route before `resources :transaction_categories` in `config/routes.rb`:

```ruby
  resource :dashboard, only: :show
```

Create `app/controllers/dashboards_controller.rb`:

```ruby
class DashboardsController < ApplicationController
  before_action :authenticate_user!

  # GET /dashboard
  def show
    authorize :dashboard
    @summary = DashboardSummary.new.summarize(user: current_user)
  end
end
```

- [ ] **Step 4: Add dashboard view**

Create `app/views/dashboards/show.html.erb`:

```erb
<% content_for :title, "Dashboard" %>

<section class="flex flex-col gap-6">
  <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <p class="text-sm font-medium uppercase tracking-wide text-body-subtle">Ledger</p>
      <h1 class="mt-1 text-3xl font-semibold tracking-tight text-heading">Dashboard</h1>
      <p class="mt-2 max-w-2xl text-sm text-body">A quick snapshot of your Rails ledger.</p>
    </div>

    <%= render(ButtonComponent.new(href: new_transaction_path)) { "New transaction" } %>
  </div>

  <div class="grid gap-4 md:grid-cols-3">
    <div class="bg-neutral-primary-soft border border-default rounded-base p-5 shadow-xs">
      <p class="text-sm font-medium text-body-subtle">Total balance</p>
      <p class="mt-2 text-3xl font-semibold text-heading"><%= number_to_currency(@summary.total_balance_cents / 100.0, unit: "") %></p>
    </div>
    <div class="bg-neutral-primary-soft border border-default rounded-base p-5 shadow-xs">
      <p class="text-sm font-medium text-body-subtle">Accounts</p>
      <p class="mt-2 text-3xl font-semibold text-heading"><%= @summary.account_count %></p>
    </div>
    <div class="bg-neutral-primary-soft border border-default rounded-base p-5 shadow-xs">
      <p class="text-sm font-medium text-body-subtle">Transactions</p>
      <p class="mt-2 text-3xl font-semibold text-heading"><%= @summary.transaction_count %></p>
    </div>
  </div>

  <div class="bg-neutral-primary-soft border border-default rounded-base shadow-xs">
    <div class="flex items-center justify-between border-b border-default px-5 py-4">
      <h2 class="text-lg font-semibold text-heading">Recent transactions</h2>
      <%= link_to "View all", transactions_path, class: "text-sm font-medium text-fg-brand hover:underline" %>
    </div>

    <% if @summary.recent_transactions.any? %>
      <ul class="divide-y divide-default">
        <% @summary.recent_transactions.each do |transaction| %>
          <li id="<%= dom_id(transaction) %>" class="flex flex-col gap-2 px-5 py-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h3 class="font-medium text-heading"><%= transaction.comment.presence || transaction.transaction_kind.humanize %></h3>
              <p class="mt-1 text-sm text-body-subtle"><%= transaction.account.name %> · <%= transaction.transaction_category.name %></p>
            </div>
            <p class="text-sm font-semibold text-heading"><%= transaction.source_amount_cents %> cents</p>
          </li>
        <% end %>
      </ul>
    <% else %>
      <div class="px-5 py-8 text-center">
        <h3 class="text-lg font-semibold text-heading">No transactions yet</h3>
        <p class="mt-2 text-sm text-body">Record your first transaction to populate this dashboard.</p>
      </div>
    <% end %>
  </div>
</section>
```

- [ ] **Step 5: Add dashboard navigation**

In `app/views/layouts/application.html.erb`, add this link before signed-in `Accounts`:

```erb
<%= link_to "Dashboard", dashboard_path, class: "text-sm font-medium text-body hover:text-heading" %>
```

- [ ] **Step 6: Run dashboard integration test to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/dashboard_test.rb
```

Expected: PASS.

- [ ] **Step 7: Commit dashboard UI**

Run:

```bash
git add app/policies/dashboard_policy.rb app/controllers/dashboards_controller.rb app/views/dashboards config/routes.rb app/views/layouts/application.html.erb test/integration/dashboard_test.rb
git commit -m "feat: add ledger dashboard"
```

## Task 3: Slice Verification

**Files:**
- Verify: all files changed in Tasks 1-2

- [ ] **Step 1: Run targeted tests**

Run:

```bash
mise exec -- bin/rails test test/services/dashboard_summary_test.rb test/integration/dashboard_test.rb
```

Expected: PASS.

- [ ] **Step 2: Run full test suite**

Run:

```bash
mise exec -- bin/rails test
```

Expected: PASS.

- [ ] **Step 3: Run Ruby lint**

Run:

```bash
mise exec -- bin/rubocop
```

Expected: PASS.

- [ ] **Step 4: Run ERB lint for changed views**

Run:

```bash
mise exec -- bundle exec erb_lint app/views/dashboards app/views/layouts/application.html.erb
```

Expected: PASS.

- [ ] **Step 5: Commit lint-only fixes if needed**

If lint changed files, run:

```bash
git add app test config
git commit -m "style: clean dashboard slice"
```

Expected: commit is created only if lint produced edits.

## Self-Review Checklist

- Spec coverage: Implements Phase 1 `resource :dashboard, only: :show` with scoped accounts and recent transactions. Full statistics, trends, reconciliation, and insight explorers remain Phase 2.
- Placeholder scan: every step has concrete files, code, commands, and expected outcomes.
- Type consistency: uses `DashboardSummary#summarize(user:)`, `dashboard_path`, and existing transaction/account/category associations consistently.
