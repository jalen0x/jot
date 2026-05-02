# ezBookkeeping Transaction Filters Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add visible transaction filters for type, account, category, and tag on the Rails transaction list.

**Architecture:** Keep filtering in `LedgerQuery#list_transactions`; `TransactionsController#index` loads user-owned filter collections and passes permitted query params. The index view renders a simple GET form using semantic Flowbite classes so filter state remains shareable in the URL.

**Tech Stack:** Rails 8.1, Devise, Pundit, Hotwire/Turbo, Flowbite semantic classes, Minitest, FactoryBot.

---

## File Structure

- `test/integration/transactions_filters_test.rb`: HTTP-level filter coverage for user-visible query params and cross-user decoys.
- `app/controllers/transactions_controller.rb`: load filter collections on index.
- `app/views/transactions/index.html.erb`: GET filter form and clear link.

## Task 1: Transaction Filter UI

**Files:**
- Create: `test/integration/transactions_filters_test.rb`
- Modify: `app/controllers/transactions_controller.rb`
- Modify: `app/views/transactions/index.html.erb`

- [ ] **Step 1: Write failing transaction filter integration tests**

Create `test/integration/transactions_filters_test.rb`:

```ruby
require "test_helper"

class TransactionsFiltersTest < ActionDispatch::IntegrationTest
  test "filters transactions by type and category" do
    user = create(:user)
    account = create_account(user: user, name: "Cash")
    income_category = create_category(user: user, name: "Salary", category_type: :income)
    expense_category = create_category(user: user, name: "Food", category_type: :expense)
    create_transaction(user: user, account: account, category: income_category, transaction_kind: :income, comment: "Paycheck")
    create_transaction(user: user, account: account, category: expense_category, transaction_kind: :expense, comment: "Groceries")
    create_transaction(user: create(:user), comment: "Other Paycheck")
    sign_in user

    get transactions_path, params: { transaction_kind: "income", transaction_category_id: income_category.id.to_s }

    assert_response :success
    assert_select "form[action='#{transactions_path}'][method='get']"
    assert_select "li", text: /Paycheck/i
    assert_select "li", text: /Groceries/i, count: 0
    assert_select "li", text: /Other Paycheck/i, count: 0
  end

  test "filters transactions by account and tag" do
    user = create(:user)
    matching_account = create_account(user: user, name: "Business Checking")
    other_account = create_account(user: user, name: "Personal Cash")
    category = create_category(user: user, name: "Food", category_type: :expense)
    matching_tag = create_tag(user: user, name: "Business")
    other_tag = create_tag(user: user, name: "Personal")
    matching = create_transaction(user: user, account: matching_account, category: category, transaction_kind: :expense, comment: "Client lunch")
    other = create_transaction(user: user, account: other_account, category: category, transaction_kind: :expense, comment: "Family lunch")
    TransactionTagging.create!(user: user, ledger_transaction: matching, transaction_tag: matching_tag)
    TransactionTagging.create!(user: user, ledger_transaction: other, transaction_tag: other_tag)
    sign_in user

    get transactions_path, params: { account_id: matching_account.id.to_s, tag_id: matching_tag.id.to_s }

    assert_response :success
    assert_select "li", text: /Client lunch/i
    assert_select "li", text: /Family lunch/i, count: 0
  end

  private

  def create_transaction(user:, comment:, account: nil, category: nil, transaction_kind: :expense)
    account ||= create_account(user: user, name: "Cash #{comment}")
    category ||= create_category(user: user, name: "Food #{comment}", category_type: transaction_kind)

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: transaction_kind,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1000,
      destination_amount_cents: 0,
      comment: comment
    )
  end

  def create_account(user:, name:)
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

  def create_tag(user:, name:)
    TransactionTag.create!(user: user, name: name, display_order: 1)
  end
end
```

- [ ] **Step 2: Run filter tests to verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/transactions_filters_test.rb
```

Expected: FAIL because the index has no filter form.

- [ ] **Step 3: Load filter collections in the controller**

Modify `app/controllers/transactions_controller.rb` index action:

```ruby
  def index
    authorize Transaction
    @transactions = LedgerQuery.new.list_transactions(user: current_user, filters: filter_params)
    load_filter_collections
  end
```

Add this private method:

```ruby
  def load_filter_collections
    @filter_accounts = current_user.accounts.kept.order(:display_order, :name)
    @filter_categories = current_user.transaction_categories.kept.order(:category_type, :display_order, :name)
    @filter_tags = current_user.transaction_tags.kept.order(:display_order, :name)
  end
```

- [ ] **Step 4: Add filter form to transactions index**

In `app/views/transactions/index.html.erb`, add this after the page header block and before the transactions list:

```erb
  <% field_classes = "bg-neutral-secondary-medium border border-default-medium text-heading text-sm rounded-base focus:ring-brand focus:border-brand block w-full px-3 py-2.5 shadow-xs placeholder:text-body" %>

  <%= form_with url: transactions_path, method: :get, class: "bg-neutral-primary-soft border border-default rounded-base p-5 shadow-xs" do |form| %>
    <div class="grid gap-4 md:grid-cols-4">
      <div>
        <%= form.label :transaction_kind, "Type", class: "block mb-2 text-sm font-medium text-heading" %>
        <%= form.select :transaction_kind, Transaction.transaction_kinds.except("balance_adjustment").keys.map { |key| [ key.humanize, key ] }, { include_blank: "All types", selected: params[:transaction_kind] }, class: field_classes %>
      </div>
      <div>
        <%= form.label :account_id, "Account", class: "block mb-2 text-sm font-medium text-heading" %>
        <%= form.collection_select :account_id, @filter_accounts, :id, :name, { include_blank: "All accounts", selected: params[:account_id] }, class: field_classes %>
      </div>
      <div>
        <%= form.label :transaction_category_id, "Category", class: "block mb-2 text-sm font-medium text-heading" %>
        <%= form.collection_select :transaction_category_id, @filter_categories, :id, :name, { include_blank: "All categories", selected: params[:transaction_category_id] }, class: field_classes %>
      </div>
      <div>
        <%= form.label :tag_id, "Tag", class: "block mb-2 text-sm font-medium text-heading" %>
        <%= form.collection_select :tag_id, @filter_tags, :id, :name, { include_blank: "All tags", selected: params[:tag_id] }, class: field_classes %>
      </div>
    </div>

    <div class="mt-4 flex justify-end gap-3">
      <%= render(ButtonComponent.new(variant: :secondary, href: transactions_path)) { "Clear" } %>
      <%= render(ButtonComponent.new(type: :submit)) { "Apply filters" } %>
    </div>
  <% end %>
```

- [ ] **Step 5: Run filter tests to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/transactions_filters_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit transaction filters**

Run:

```bash
git add app/controllers/transactions_controller.rb app/views/transactions/index.html.erb test/integration/transactions_filters_test.rb
git commit -m "feat: filter ledger transactions"
```

## Task 2: Slice Verification

**Files:**
- Verify: changed files from Task 1

- [ ] **Step 1: Run targeted tests**

Run:

```bash
mise exec -- bin/rails test test/integration/transactions_filters_test.rb test/integration/transactions_test.rb test/services/ledger_query_test.rb
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
mise exec -- bundle exec erb_lint app/views/transactions
```

Expected: PASS.

- [ ] **Step 5: Commit lint-only fixes if needed**

If lint changed files, run:

```bash
git add app test
git commit -m "style: clean transaction filters slice"
```

Expected: commit is created only if lint produced edits.

## Self-Review Checklist

- Spec coverage: Implements Phase 1 user-visible transaction filtering for type, account, category, and tag using existing `LedgerQuery`.
- Placeholder scan: every step has concrete files, code, commands, and expected outcomes.
- Type consistency: query params match `LedgerQuery#list_transactions` filter keys.
