# ezBookkeeping Data Export Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a minimum Rails-native CSV export for the current user's transactions.

**Architecture:** `DataExport#transactions_csv` builds a CSV string from scoped Rails ledger records. `DataExportsController#create` authenticates, authorizes a non-AR export resource, and streams the generated CSV with `send_data`; no external I/O or background job is needed for this small synchronous export slice.

**Tech Stack:** Rails 8.1, Ruby CSV stdlib, Devise, Pundit, Minitest, FactoryBot.

---

## File Structure

- `app/services/data_export.rb`: generate current-user transaction CSV.
- `test/services/data_export_test.rb`: CSV shape and current-user scoping coverage.
- `app/policies/data_export_policy.rb`: signed-in export authorization.
- `app/controllers/data_exports_controller.rb`: CSV download boundary.
- `config/routes.rb`: canonical `resources :data_exports, only: :create` route.
- `app/views/reports/show.html.erb`: export button from reports page.
- `test/integration/data_exports_test.rb`: authentication, content type, and scoping coverage.

## Task 1: DataExport Service

**Files:**
- Create: `test/services/data_export_test.rb`
- Create: `app/services/data_export.rb`

- [ ] **Step 1: Write failing data export service tests**

Create `test/services/data_export_test.rb`:

```ruby
require "test_helper"
require "csv"

class DataExportTest < ActiveSupport::TestCase
  test "exports current user's transactions as CSV" do
    user = create(:user)
    other_user = create(:user)
    tag = create_tag(user: user, name: "Business")
    transaction = create_transaction(user: user, comment: "Client lunch")
    TransactionTagging.create!(user: user, ledger_transaction: transaction, transaction_tag: tag)
    create_transaction(user: other_user, comment: "Other lunch")

    csv = DataExport.new.transactions_csv(user: user)
    rows = CSV.parse(csv, headers: true)

    assert_equal [ "Transacted At", "Type", "Account", "Destination Account", "Category", "Source Amount Cents", "Destination Amount Cents", "Tags", "Comment" ], rows.headers
    assert_equal 1, rows.length
    assert_equal "Client lunch", rows[0]["Comment"]
    assert_equal "Business", rows[0]["Tags"]
    assert_equal "expense", rows[0]["Type"]
  end

  private

  def create_transaction(user:, comment:)
    account = create_account(user: user, name: "Cash")
    category = create_category(user: user, name: "Food", category_type: :expense)

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1200,
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

- [ ] **Step 2: Run data export service test to verify RED**

Run:

```bash
mise exec -- bin/rails test test/services/data_export_test.rb
```

Expected: FAIL with `uninitialized constant DataExport`.

- [ ] **Step 3: Implement DataExport**

Create `app/services/data_export.rb`:

```ruby
require "csv"

class DataExport
  HEADERS = [
    "Transacted At",
    "Type",
    "Account",
    "Destination Account",
    "Category",
    "Source Amount Cents",
    "Destination Amount Cents",
    "Tags",
    "Comment"
  ].freeze

  def transactions_csv(user:)
    CSV.generate(headers: true) do |csv|
      csv << HEADERS

      user.transactions.kept.includes(:account, :destination_account, :transaction_category, :transaction_tags).order(:transacted_at, :id).each do |transaction|
        csv << row_for(transaction)
      end
    end
  end

  private

  def row_for(transaction)
    [
      transaction.transacted_at.iso8601,
      transaction.transaction_kind,
      transaction.account.name,
      transaction.destination_account&.name,
      transaction.transaction_category.name,
      transaction.source_amount_cents,
      transaction.destination_amount_cents,
      transaction.transaction_tags.map(&:name).join("; "),
      transaction.comment
    ]
  end
end
```

- [ ] **Step 4: Run data export service test to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/services/data_export_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit DataExport**

Run:

```bash
git add app/services/data_export.rb test/services/data_export_test.rb
git commit -m "feat: export transactions as csv"
```

## Task 2: Data Export Controller

**Files:**
- Create: `test/integration/data_exports_test.rb`
- Create: `app/policies/data_export_policy.rb`
- Create: `app/controllers/data_exports_controller.rb`
- Modify: `config/routes.rb`
- Modify: `app/views/reports/show.html.erb`

- [ ] **Step 1: Write failing data export integration tests**

Create `test/integration/data_exports_test.rb`:

```ruby
require "test_helper"
require "csv"

class DataExportsTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    post data_exports_path

    assert_redirected_to new_user_session_path
  end

  test "downloads current user's transaction CSV" do
    user = create(:user)
    other_user = create(:user)
    create_transaction(user: user, comment: "Client lunch")
    create_transaction(user: other_user, comment: "Other lunch")
    sign_in user

    post data_exports_path

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match(/transactions-\d{4}-\d{2}-\d{2}\.csv/, response.headers["Content-Disposition"])
    rows = CSV.parse(response.body, headers: true)
    assert_equal [ "Client lunch" ], rows.map { |row| row["Comment"] }
  end

  private

  def create_transaction(user:, comment:)
    account = create_account(user: user, name: "Cash")
    category = create_category(user: user, name: "Food", category_type: :expense)

    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 10:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1200,
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
end
```

- [ ] **Step 2: Run data export integration test to verify RED**

Run:

```bash
mise exec -- bin/rails test test/integration/data_exports_test.rb
```

Expected: FAIL with missing `data_exports_path`.

- [ ] **Step 3: Add policy, route, and controller**

Create `app/policies/data_export_policy.rb`:

```ruby
class DataExportPolicy < ApplicationPolicy
  def create? = user.present?
end
```

Add this route after `resource :reports` in `config/routes.rb`:

```ruby
  resources :data_exports, only: :create
```

Create `app/controllers/data_exports_controller.rb`:

```ruby
class DataExportsController < ApplicationController
  before_action :authenticate_user!

  # POST /data_exports
  def create
    authorize :data_export
    csv = DataExport.new.transactions_csv(user: current_user)

    send_data csv,
      filename: "transactions-#{Time.zone.today.iso8601}.csv",
      type: "text/csv; charset=utf-8"
  end
end
```

- [ ] **Step 4: Add export button to reports page**

In `app/views/reports/show.html.erb`, add this button in the header section under the intro paragraph:

```erb
    <div class="mt-4">
      <%= button_to "Export transactions CSV", data_exports_path, class: "text-body bg-neutral-secondary-medium box-border border border-default-medium hover:bg-neutral-tertiary-medium hover:text-heading focus:ring-4 focus:ring-neutral-tertiary shadow-xs font-medium leading-5 rounded-base text-sm px-4 py-2.5 focus:outline-none" %>
    </div>
```

- [ ] **Step 5: Run data export integration test to verify GREEN**

Run:

```bash
mise exec -- bin/rails test test/integration/data_exports_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit data export controller**

Run:

```bash
git add app/policies/data_export_policy.rb app/controllers/data_exports_controller.rb config/routes.rb app/views/reports/show.html.erb test/integration/data_exports_test.rb
git commit -m "feat: download transaction exports"
```

## Task 3: Slice Verification

**Files:**
- Verify: all files changed in Tasks 1-2

- [ ] **Step 1: Run targeted tests**

Run:

```bash
mise exec -- bin/rails test test/services/data_export_test.rb test/integration/data_exports_test.rb test/integration/reports_test.rb
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
mise exec -- bundle exec erb_lint app/views/reports
```

Expected: PASS.

- [ ] **Step 5: Commit lint-only fixes if needed**

If lint changed files, run:

```bash
git add app test config
git commit -m "style: clean data export slice"
```

Expected: commit is created only if lint produced edits.

## Self-Review Checklist

- Spec coverage: Implements Phase 3 minimum `DataExport` CSV generation and download route. Import parsing, async exports, multiple formats, and data clearing remain later Phase 3 slices.
- Placeholder scan: every step has concrete files, code, commands, and expected outcomes.
- Type consistency: exported CSV headers match service and integration tests.
