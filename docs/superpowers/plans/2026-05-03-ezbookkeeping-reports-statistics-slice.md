# ezBookkeeping Reports Statistics Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Rails-native reports page with basic income, expense, net, and category totals for a date range.

**Architecture:** `LedgerStatistics#summarize_transactions` owns read-only reporting queries scoped to the current user. `ReportsController#show` authenticates, authorizes a non-AR reports resource, parses date params at the HTTP boundary, and renders SSR cards/tables.

**Tech Stack:** Rails 8.1, PostgreSQL, Devise, Pundit, Flowbite semantic classes, Minitest, FactoryBot.

---

## File Structure

- `app/services/ledger_statistics.rb`: income/expense/net/category totals.
- `test/services/ledger_statistics_test.rb`: scoped date-range and category total coverage with decoys.
- `app/policies/report_policy.rb`: signed-in reports authorization.
- `app/controllers/reports_controller.rb`: report boundary and date params.
- `app/views/reports/show.html.erb`: SSR reports page.
- `config/routes.rb`: canonical `resource :reports` route.
- `app/views/layouts/application.html.erb`: signed-in Reports nav link.
- `test/integration/reports_test.rb`: auth and page scoping coverage.

## Task 1: LedgerStatistics Service

**Files:**
- Create: `test/services/ledger_statistics_test.rb`
- Create: `app/services/ledger_statistics.rb`

- [ ] **Step 1: Write failing statistics service tests**

Create `test/services/ledger_statistics_test.rb`:

```ruby
require "test_helper"

class LedgerStatisticsTest < ActiveSupport::TestCase
  test "summarizes income expense net and category totals for current user and date range" do
    user = create(:user)
    other_user = create(:user)
    salary = create_category(user: user, name: "Salary", category_type: :income)
    food = create_category(user: user, name: "Food", category_type: :expense)
    create_transaction(user: user, category: salary, transaction_kind: :income, amount_cents: 5_000, transacted_at: Time.zone.parse("2026-05-03 09:00:00"))
    create_transaction(user: user, category: food, transaction_kind: :expense, amount_cents: 1_200, transacted_at: Time.zone.parse("2026-05-03 10:00:00"))
    create_transaction(user: user, category: food, transaction_kind: :expense, amount_cents: 300, transacted_at: Time.zone.parse("2026-05-04 10:00:00"))
    create_transaction(user: user, category: salary, transaction_kind: :income, amount_cents: 9_999, transacted_at: Time.zone.parse("2026-06-01 10:00:00"))
    create_transaction(user: other_user, transaction_kind: :income, amount_cents: 7_777, transacted_at: Time.zone.parse("2026-05-03 10:00:00"))

    summary = LedgerStatistics.new.summarize_transactions(
      user: user,
      range: Time.zone.parse("2026-05-01")..Time.zone.parse("2026-05-31 23:59:59")
    )

    assert_equal 5_000, summary.income_cents
    assert_equal 1_500, summary.expense_cents
    assert_equal 3_500, summary.net_cents
    assert_equal({ "Salary" => 5_000, "Food" => -1_500 }, summary.category_totals.transform_values(&:itself))
  end

  test "ignores transfers and discarded transactions" do
    user = create(:user)
    income_category = create_category(user: user, name: "Salary", category_type: :income)
    transfer_category = create_category(user: user, name: "Transfer", category_type: :transfer)
    discarded = create_transaction(user: user, category: income_category, transaction_kind: :income, amount_cents: 5_000)
    discarded.discard!
    create_transfer(user: user, category: transfer_category, amount_cents: 2_000)

    summary = LedgerStatistics.new.summarize_transactions(user: user, range: Time.zone.parse("2026-05-01")..Time.zone.parse("2026-05-31 23:59:59"))

    assert_equal 0, summary.income_cents
    assert_equal 0, summary.expense_cents
    assert_empty summary.category_totals
  end

  private

  def create_transaction(user:, transaction_kind:, amount_cents:, transacted_at: Time.zone.parse("2026-05-03 10:00:00"), category: nil)
    category ||= create_category(user: user, name: transaction_kind.to_s.humanize, category_type: transaction_kind)
    account = create_account(user: user)

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: transaction_kind,
      transacted_at: transacted_at,
      timezone_utc_offset_minutes: 0,
      source_amount_cents: amount_cents,
      destination_amount_cents: 0
    )
  end

  def create_transfer(user:, category:, amount_cents:)
    Transaction.create!(
      user: user,
      account: create_account(user: user, name: "Checking"),
      destination_account: create_account(user: user, name: "Savings"),
      transaction_category: category,
      transaction_kind: :transfer,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: amount_cents,
      destination_amount_cents: amount_cents
    )
  end

  def create_account(user:, name: "Cash")
    Account.create!(
      user: user,
      name: name,
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: 0,
      display_order: 1
    )
  end

  def create_category(user:, name:, category_type:)
    TransactionCategory.create!(
      user: user,
      name: name,
      category_type: category_type,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end
end
```

- [ ] **Step 2: Run statistics tests to verify RED**

Run:

```bash
mise exec -- bin/rails test test/services/ledger_statistics_test.rb
```

Expected: FAIL with `uninitialized constant LedgerStatistics`.

- [ ] **Step 3: Implement LedgerStatistics**

Create `app/services/ledger_statistics.rb`:

```ruby
class LedgerStatistics
  def summarize_transactions(user:, range:)
    transactions = user.transactions.kept.includes(:transaction_category).where(transacted_at: range)
    income_cents = transactions.income.sum(:source_amount_cents)
    expense_cents = transactions.expense.sum(:source_amount_cents)

    Result.new(
      income_cents: income_cents,
      expense_cents: expense_cents,
      net_cents: income_cents - expense_cents,
      category_totals: category_totals(transactions)
    )
  end

  private

  def category_totals(transactions)
    totals = Hash.new(0)

    transactions.each do |transaction|
      next unless transaction.income? || transaction.expense?

      amount = transaction.income? ? transaction.source_amount_cents : -transaction.source_amount_cents
      totals[transaction.transaction_category.name] += amount
    end

    totals
  end

  class Result
    attr_reader :income_cents, :expense_cents, :net_cents, :category_totals

    def initialize(income_cents:, expense_cents:, net_cents:, category_totals:)
      @income_cents = income_cents
      @expense_cents = expense_cents
      @net_cents = net_cents
      @category_totals = category_totals
    end
  end
end
```

- [ ] **Step 4: Run statistics tests to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/services/ledger_statistics_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit LedgerStatistics**

Run:

```bash
git add app/services/ledger_statistics.rb test/services/ledger_statistics_test.rb
git commit -m "feat: summarize ledger reports"
```

## Task 2: Reports Page

**Files:**
- Create: `test/integration/reports_test.rb`
- Create: `app/policies/report_policy.rb`
- Create: `app/controllers/reports_controller.rb`
- Create: `app/views/reports/show.html.erb`
- Modify: `config/routes.rb`
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Write failing reports integration tests**

Create `test/integration/reports_test.rb`:

```ruby
require "test_helper"

class ReportsTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get reports_path

    assert_redirected_to new_user_session_path
  end

  test "shows current user's report totals for selected range" do
    user = create(:user)
    other_user = create(:user)
    salary = create_category(user: user, name: "Salary", category_type: :income)
    food = create_category(user: user, name: "Food", category_type: :expense)
    create_transaction(user: user, category: salary, transaction_kind: :income, amount_cents: 5_000, comment: "Paycheck")
    create_transaction(user: user, category: food, transaction_kind: :expense, amount_cents: 1_200, comment: "Groceries")
    create_transaction(user: other_user, transaction_kind: :income, amount_cents: 9_999, comment: "Other Paycheck")
    sign_in user

    get reports_path, params: { start_date: "2026-05-01", end_date: "2026-05-31" }

    assert_response :success
    assert_select "h1", text: /reports/i
    assert_select "p", text: /50.00/
    assert_select "p", text: /12.00/
    assert_select "li", text: /Salary/i
    assert_select "li", text: /Food/i
    assert_select "li", text: /Other/i, count: 0
  end

  private

  def create_transaction(user:, transaction_kind:, amount_cents:, comment:, category: nil)
    category ||= create_category(user: user, name: transaction_kind.to_s.humanize, category_type: transaction_kind)
    account = create_account(user: user)

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: transaction_kind,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: amount_cents,
      destination_amount_cents: 0,
      comment: comment
    )
  end

  def create_account(user:)
    Account.create!(
      user: user,
      name: "Cash",
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: 0,
      display_order: 1
    )
  end

  def create_category(user:, name:, category_type:)
    TransactionCategory.create!(
      user: user,
      name: name,
      category_type: category_type,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end
end
```

- [ ] **Step 2: Run reports integration tests to verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/reports_test.rb
```

Expected: FAIL with missing `reports_path`.

- [ ] **Step 3: Add policy, route, and controller**

Create `app/policies/report_policy.rb`:

```ruby
class ReportPolicy < ApplicationPolicy
  def show? = user.present?
end
```

Add this route after `resource :dashboard` in `config/routes.rb`:

```ruby
  resource :reports, only: :show
```

Create `app/controllers/reports_controller.rb`:

```ruby
class ReportsController < ApplicationController
  before_action :authenticate_user!

  # GET /reports
  def show
    authorize :report
    @start_date = parse_date(params[:start_date]) || Time.zone.today.beginning_of_month
    @end_date = parse_date(params[:end_date]) || Time.zone.today.end_of_month
    @summary = LedgerStatistics.new.summarize_transactions(user: current_user, range: @start_date.beginning_of_day..@end_date.end_of_day)
  end

  private

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value)
  rescue Date::Error
    nil
  end
end
```

- [ ] **Step 4: Add reports view**

Create `app/views/reports/show.html.erb`:

```erb
<% content_for :title, "Reports" %>
<% field_classes = "bg-neutral-secondary-medium border border-default-medium text-heading text-sm rounded-base focus:ring-brand focus:border-brand block w-full px-3 py-2.5 shadow-xs placeholder:text-body" %>

<section class="flex flex-col gap-6">
  <div>
    <p class="text-sm font-medium uppercase tracking-wide text-body-subtle">Ledger</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight text-heading">Reports</h1>
    <p class="mt-2 max-w-2xl text-sm text-body">Review income, expenses, and category totals for a date range.</p>
  </div>

  <%= form_with url: reports_path, method: :get, class: "bg-neutral-primary-soft border border-default rounded-base p-5 shadow-xs" do |form| %>
    <div class="grid gap-4 sm:grid-cols-2">
      <div>
        <%= form.label :start_date, "Start date", class: "block mb-2 text-sm font-medium text-heading" %>
        <%= form.date_field :start_date, value: @start_date, class: field_classes %>
      </div>
      <div>
        <%= form.label :end_date, "End date", class: "block mb-2 text-sm font-medium text-heading" %>
        <%= form.date_field :end_date, value: @end_date, class: field_classes %>
      </div>
    </div>
    <div class="mt-4 flex justify-end"><%= render(ButtonComponent.new(type: :submit)) { "Update report" } %></div>
  <% end %>

  <div class="grid gap-4 md:grid-cols-3">
    <div class="bg-neutral-primary-soft border border-default rounded-base p-5 shadow-xs">
      <p class="text-sm font-medium text-body-subtle">Income</p>
      <p class="mt-2 text-3xl font-semibold text-heading"><%= number_to_currency(@summary.income_cents / 100.0, unit: "") %></p>
    </div>
    <div class="bg-neutral-primary-soft border border-default rounded-base p-5 shadow-xs">
      <p class="text-sm font-medium text-body-subtle">Expense</p>
      <p class="mt-2 text-3xl font-semibold text-heading"><%= number_to_currency(@summary.expense_cents / 100.0, unit: "") %></p>
    </div>
    <div class="bg-neutral-primary-soft border border-default rounded-base p-5 shadow-xs">
      <p class="text-sm font-medium text-body-subtle">Net</p>
      <p class="mt-2 text-3xl font-semibold text-heading"><%= number_to_currency(@summary.net_cents / 100.0, unit: "") %></p>
    </div>
  </div>

  <div class="bg-neutral-primary-soft border border-default rounded-base shadow-xs">
    <div class="border-b border-default px-5 py-4">
      <h2 class="text-lg font-semibold text-heading">Category totals</h2>
    </div>

    <% if @summary.category_totals.any? %>
      <ul class="divide-y divide-default">
        <% @summary.category_totals.each do |name, amount_cents| %>
          <li class="flex items-center justify-between px-5 py-4">
            <span class="font-medium text-heading"><%= name %></span>
            <span class="text-sm font-semibold text-heading"><%= number_to_currency(amount_cents / 100.0, unit: "") %></span>
          </li>
        <% end %>
      </ul>
    <% else %>
      <p class="px-5 py-8 text-center text-sm text-body">No income or expense transactions in this range.</p>
    <% end %>
  </div>
</section>
```

- [ ] **Step 5: Add reports navigation**

In `app/views/layouts/application.html.erb`, add this link after signed-in `Dashboard`:

```erb
<%= link_to "Reports", reports_path, class: "text-sm font-medium text-body hover:text-heading" %>
```

- [ ] **Step 6: Run reports integration test to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/reports_test.rb
```

Expected: PASS.

- [ ] **Step 7: Commit reports page**

Run:

```bash
git add app/policies/report_policy.rb app/controllers/reports_controller.rb app/views/reports config/routes.rb app/views/layouts/application.html.erb test/integration/reports_test.rb
git commit -m "feat: add ledger reports"
```

## Task 3: Slice Verification

**Files:**
- Verify: all files changed in Tasks 1-2

- [ ] **Step 1: Run targeted tests**

Run:

```bash
mise exec -- bin/rails test test/services/ledger_statistics_test.rb test/integration/reports_test.rb
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
mise exec -- bundle exec erb_lint app/views/reports app/views/layouts/application.html.erb
```

Expected: PASS.

- [ ] **Step 5: Commit lint-only fixes if needed**

If lint changed files, run:

```bash
git add app test config
git commit -m "style: clean reports slice"
```

Expected: commit is created only if lint produced edits.

## Self-Review Checklist

- Spec coverage: Implements Phase 2 minimum `LedgerStatistics` and `resource :reports` page for income, expense, net, and category totals. Trends, asset trends, reconciliation, and saved insight explorers remain later Phase 2 slices.
- Placeholder scan: every step has concrete files, code, commands, and expected outcomes.
- Type consistency: service returns cents; views format cents as currency-like decimal output.
