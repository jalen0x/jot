# ezBookkeeping Phase 0 Account Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the parity-inventory foundation and the first Rails-native account slice with opening-balance ledger transactions.

**Architecture:** Phase 0 adds a read-only source inventory seam and parity docs so the rewrite remains traceable to the Go/Vue source. Phase 1 starts with user-owned accounts and opening-balance transactions, with business behavior in `AccountCreator#create_account` and controllers limited to HTTP coercion, authorization, and rendering.

**Tech Stack:** Rails 8.1, PostgreSQL SQL schema, Devise, Pundit, Discard, Prefixed IDs, ViewComponent, Hotwire/Turbo, Flowbite semantic classes, Minitest, FactoryBot.

---

## File Structure

- `Gemfile` / `Gemfile.lock`: add `factory_bot_rails` for new Rails test data, matching `AGENTS.md` test standards.
- `test/test_helper.rb`: include FactoryBot syntax and Devise integration helpers.
- `test/factories/users.rb`: factory for valid Devise users.
- `lib/ezbookkeeping/source_inventory.rb`: read-only parser for source Go/Vue files.
- `test/lib/ezbookkeeping/source_inventory_test.rb`: focused tests for the parser.
- `lib/tasks/ezbookkeeping.rake`: rake entry point for inventory inspection.
- `docs/ezbookkeeping/parity-map.md`: phase map from source features/endpoints/routes/models to Rails work.
- `docs/ezbookkeeping/data-migration-map.md`: initial source-model to Rails-table migration map.
- `db/migrate/20260503090000_create_core_ledger_tables.rb`: accounts and transactions tables with comments, constraints, foreign keys, and indexes.
- `app/models/account.rb`: user-owned account model with two-level self relation and soft delete.
- `app/models/transaction.rb`: user-owned ledger transaction model.
- `app/models/user.rb`: associations to accounts and transactions.
- `app/services/account_creator.rb`: first account use-case service and nested Result.
- `app/policies/account_policy.rb`: ownership policy and scope.
- `app/controllers/accounts_controller.rb`: accounts index/new/create boundary.
- `app/views/accounts/index.html.erb`: account list and empty state.
- `app/views/accounts/new.html.erb`: new account page.
- `app/views/accounts/_form.html.erb`: account form with strict locals.
- `app/views/layouts/application.html.erb`: signed-in nav link to accounts.
- `config/routes.rb`: canonical `resources :accounts, only: [:index, :new, :create]`.
- Tests under `test/models`, `test/services`, and `test/integration` cover the concrete ledger/account risks.

## Task 1: FactoryBot Test Setup

**Files:**
- Modify: `Gemfile`
- Modify: `test/test_helper.rb`
- Create: `test/factories/users.rb`

- [ ] **Step 1: Add the FactoryBot dependency**

Modify the `group :test do` block in `Gemfile` so it includes `factory_bot_rails`:

```ruby
group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # Build realistic test data without adding new Rails fixtures.
  gem "factory_bot_rails"

  # Mock HTTP requests in tests
  gem "webmock"
end
```

- [ ] **Step 2: Install the new gem**

Run:

```bash
bundle install
```

Expected: `Gemfile.lock` changes and Bundler completes without errors.

- [ ] **Step 3: Configure test helpers**

Modify `test/test_helper.rb` to include FactoryBot and Devise helpers:

```ruby
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "factory_bot_rails"
require_relative "support/confidence_check"

module ActiveSupport
  class TestCase
    include TestSupport::ConfidenceCheck
    include FactoryBot::Syntax::Methods

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
```

- [ ] **Step 4: Add a valid user factory**

Create `test/factories/users.rb`:

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    first_name { "Test" }
    last_name { "User" }
  end
end
```

- [ ] **Step 5: Verify baseline tests still pass**

Run:

```bash
bin/rails test
```

Expected: all existing tests pass.

- [ ] **Step 6: Commit test setup**

Run:

```bash
git add Gemfile Gemfile.lock test/test_helper.rb test/factories/users.rb
git commit -m "test: add factory bot setup"
```

## Task 2: Source Inventory Parser

**Files:**
- Create: `test/lib/ezbookkeeping/source_inventory_test.rb`
- Create: `lib/ezbookkeeping/source_inventory.rb`

- [ ] **Step 1: Write the failing parser test**

Create `test/lib/ezbookkeeping/source_inventory_test.rb`:

```ruby
require "test_helper"
require "tmpdir"
require "fileutils"

class Ezbookkeeping::SourceInventoryTest < ActiveSupport::TestCase
  test "extracts source models api endpoints and frontend routes" do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "cmd"))
      FileUtils.mkdir_p(File.join(root, "src/router"))

      File.write(File.join(root, "cmd/database.go"), <<~GO)
        datastore.Container.UserDataStore.SyncStructs(new(models.Account))
        datastore.Container.UserDataStore.SyncStructs(new(models.Transaction))
      GO

      File.write(File.join(root, "cmd/webserver.go"), <<~GO)
        apiV1Route.GET("/accounts/list.json", bindApi(api.Accounts.AccountListHandler))
        apiV1Route.POST("/accounts/add.json", bindApi(api.Accounts.AccountCreateHandler))
      GO

      File.write(File.join(root, "src/router/desktop.ts"), <<~TS)
        { path: '/account/list', component: AccountListPage }
      TS

      File.write(File.join(root, "src/router/mobile.ts"), <<~TS)
        { path: '/account/add', async: asyncResolve(AccountEditPage) }
      TS

      inventory = Ezbookkeeping::SourceInventory.new(root)

      assert_equal [ "Account", "Transaction" ], inventory.models
      assert_equal [ "GET /accounts/list.json", "POST /accounts/add.json" ], inventory.api_endpoints
      assert_equal [ "/account/list" ], inventory.desktop_routes
      assert_equal [ "/account/add" ], inventory.mobile_routes
    end
  end
end
```

- [ ] **Step 2: Run the parser test to verify RED**

Run:

```bash
bin/rails test test/lib/ezbookkeeping/source_inventory_test.rb
```

Expected: FAIL with `uninitialized constant Ezbookkeeping`.

- [ ] **Step 3: Implement the parser**

Create `lib/ezbookkeeping/source_inventory.rb`:

```ruby
module Ezbookkeeping
  class SourceInventory
    API_ROUTE_PATTERN = /api(?:V1)?Route\.(GET|POST)\("([^"]+)"/
    MODEL_PATTERN = /SyncStructs\(new\(models\.(\w+)\)\)/
    ROUTE_PATTERN = /path:\s*'([^']+)'/

    def initialize(source_root)
      @source_root = Pathname(source_root)
    end

    def models
      scan(database_file, MODEL_PATTERN).sort
    end

    def api_endpoints
      read_file(webserver_file).scan(API_ROUTE_PATTERN).map { |method, path| "#{method} #{path}" }
    end

    def desktop_routes
      scan(desktop_routes_file, ROUTE_PATTERN)
    end

    def mobile_routes
      scan(mobile_routes_file, ROUTE_PATTERN)
    end

    private

    attr_reader :source_root

    def database_file = source_root.join("cmd/database.go")
    def webserver_file = source_root.join("cmd/webserver.go")
    def desktop_routes_file = source_root.join("src/router/desktop.ts")
    def mobile_routes_file = source_root.join("src/router/mobile.ts")

    def scan(path, pattern)
      read_file(path).scan(pattern).flatten
    end

    def read_file(path)
      File.read(path)
    end
  end
end
```

- [ ] **Step 4: Run the parser test to verify GREEN**

Run:

```bash
bin/rails test test/lib/ezbookkeeping/source_inventory_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit the parser**

Run:

```bash
git add lib/ezbookkeeping/source_inventory.rb test/lib/ezbookkeeping/source_inventory_test.rb
git commit -m "feat: inventory ezbookkeeping source files"
```

## Task 3: Phase 0 Rake Task And Parity Docs

**Files:**
- Create: `lib/tasks/ezbookkeeping.rake`
- Create: `docs/ezbookkeeping/parity-map.md`
- Create: `docs/ezbookkeeping/data-migration-map.md`

- [ ] **Step 1: Add the rake task**

Create `lib/tasks/ezbookkeeping.rake`:

```ruby
require "ezbookkeeping/source_inventory"

namespace :ezbookkeeping do
  desc "Print source project inventory for the Rails rewrite"
  task :source_inventory do
    source_root = ENV.fetch("EZBOOKKEEPING_SOURCE_ROOT", "/Users/Jalen/code/ezbookkeeping")
    inventory = Ezbookkeeping::SourceInventory.new(source_root)

    puts "Models: #{inventory.models.count}"
    inventory.models.each { |model| puts "  #{model}" }

    puts "API endpoints: #{inventory.api_endpoints.count}"
    inventory.api_endpoints.each { |endpoint| puts "  #{endpoint}" }

    puts "Desktop routes: #{inventory.desktop_routes.count}"
    inventory.desktop_routes.each { |route| puts "  #{route}" }

    puts "Mobile routes: #{inventory.mobile_routes.count}"
    inventory.mobile_routes.each { |route| puts "  #{route}" }
  end
end
```

- [ ] **Step 2: Run the rake task**

Run:

```bash
bin/rails ezbookkeeping:source_inventory
```

Expected: output includes `Models: 16`, `API endpoints: 102`, `Desktop routes:` and `Mobile routes:`.

- [ ] **Step 3: Add the parity map document**

Create `docs/ezbookkeeping/parity-map.md`:

```markdown
# ezBookkeeping Rails Parity Map

## Source Coverage Inputs

- README feature list: self-hosting, desktop/mobile UI, PWA, AI receipt recognition, MCP, two-level accounts/categories, pictures, locations, scheduled transactions, filtering, statistics, localization, multi-currency, exchange rates, 2FA, OIDC, app lock, import/export.
- Source models from `cmd/database.go`: User, TwoFactor, TwoFactorRecoveryCode, TokenRecord, Account, Transaction, TransactionCategory, TransactionTagGroup, TransactionTag, TransactionTagIndex, TransactionTemplate, TransactionPictureInfo, UserCustomExchangeRate, UserApplicationCloudSetting, UserExternalAuth, InsightsExplorer.
- Source API endpoint count from `cmd/webserver.go`: 102.
- Source frontend routes: desktop and mobile route files under `src/router`.

## Rails Phases

| Source capability | Rails phase | Rails artifact |
| --- | --- | --- |
| Source inventory and migration traceability | Phase 0 | `Ezbookkeeping::SourceInventory`, `docs/ezbookkeeping/*` |
| Accounts | Phase 1 | `Account`, `AccountCreator`, `AccountsController` |
| Opening balance transactions | Phase 1 | `Transaction` with `balance_adjustment` kind |
| Transaction categories | Phase 1 | `TransactionCategory` |
| Transaction tag groups and tags | Phase 1 | `TransactionTagGroup`, `TransactionTag`, `TransactionTagging` |
| Income, expense, transfers, balance adjustment | Phase 1 | `TransactionRecorder` |
| Transaction filters and list | Phase 1 | `LedgerQuery`, `TransactionsController` |
| Dashboard | Phase 1 | `DashboardController` |
| Transaction statistics and trends | Phase 2 | `LedgerStatistics`, `LedgerTrends` |
| Account reconciliation statement | Phase 2 | `AccountReconciliation` |
| Insights explorers | Phase 2 | `InsightExplorer` |
| Data export | Phase 3 | `DataExport` |
| Data import | Phase 3 | `ImportBatch`, parser jobs, `TransactionImporter` |
| Data clearing | Phase 3 | `LedgerClearance` |
| User display settings | Phase 4 | `UserPreference` or selected `User` columns |
| Custom exchange rates | Phase 4 | `UserCustomExchangeRate` |
| Automatic exchange rates | Phase 4 | `ExchangeRateSnapshot`, provider jobs |
| Sessions and API tokens | Phase 5 | Rails session/token resources |
| Two-factor authentication | Phase 5 | `TwoFactorAuthentication` resources |
| OIDC/external auth | Phase 5 | `ExternalAuthentication` resources |
| Application lock | Phase 5 | `ApplicationLock` resources |
| Transaction pictures | Phase 6 | Active Storage attachments |
| Geo locations and maps | Phase 6 | transaction location columns and map adapters |
| PWA and responsive mobile UI | Phase 6 | Rails views/assets |
| Transaction templates and schedules | Phase 7 | `TransactionTemplate`, recurring job |
| Legacy JSON API | Phase 8 | `Api::V1` adapter controllers |
| LLM receipt recognition | Phase 8 | recognition job/result resources |
| MCP support | Phase 8 | API-token-backed MCP adapter |
```

- [ ] **Step 4: Add the migration map document**

Create `docs/ezbookkeeping/data-migration-map.md`:

```markdown
# ezBookkeeping Data Migration Map

## Principles

- Rails is the new source of truth after cutover.
- Financial amounts migrate into integer cents.
- User-owned rows must map to a Rails `users.id` owner before ledger rows are imported.
- Legacy numeric IDs may be stored in `legacy_source_id` columns only during migration phases that need reconciliation.
- Import scripts must create Rails rows through the same services used by the UI when business effects matter.

## Source Model Mapping

| Source model | Rails destination | Phase | Notes |
| --- | --- | --- | --- |
| User | User plus selected preferences | 4/5 | Devise already owns authentication fields. Profile/display fields move after Phase 1. |
| TwoFactor | TwoFactorAuthentication records | 5 | Rebuild using Rails-native 2FA; do not copy Go token semantics blindly. |
| TwoFactorRecoveryCode | 2FA recovery code records | 5 | Migrate only if same 2FA implementation supports the stored format. |
| TokenRecord | Rails sessions or ApiToken | 5/8 | Public API and MCP tokens become explicit records when required. |
| Account | accounts | 1 | Preserve hierarchy, category, currency, hidden state, balance, sort order. |
| Transaction | transactions | 1 | Preserve type, account references, time, amounts, comment, location when columns exist. |
| TransactionCategory | transaction_categories | 1 | Preserve hierarchy, type, icon, color, hidden state, sort order. |
| TransactionTagGroup | transaction_tag_groups | 1 | Preserve group name and sort order. |
| TransactionTag | transaction_tags | 1 | Preserve group, name, hidden state, sort order. |
| TransactionTagIndex | transaction_taggings | 1 | Join table between transactions and tags. |
| TransactionTemplate | transaction_templates | 7 | Split normal templates and scheduled rules into explicit columns. |
| TransactionPictureInfo | Active Storage attachments | 6 | Migrate blobs only after storage backend is configured. |
| UserCustomExchangeRate | user_custom_exchange_rates | 4 | Preserve user override rates with documented base-rate conversion. |
| UserApplicationCloudSetting | application cloud settings | 4 | Implement only if the Rails product keeps this feature. |
| UserExternalAuth | external_authentications | 5 | Map provider and external identity into Rails auth model. |
| InsightsExplorer | insight_explorers | 2 | Store bounded chart/filter config JSONB, never executable code. |
```

- [ ] **Step 5: Commit Phase 0 artifacts**

Run:

```bash
git add lib/tasks/ezbookkeeping.rake docs/ezbookkeeping/parity-map.md docs/ezbookkeeping/data-migration-map.md
git commit -m "docs: map ezbookkeeping parity phases"
```

## Task 4: Core Ledger Tables

**Files:**
- Create: `test/models/account_test.rb`
- Create: `test/models/transaction_test.rb`
- Create: `db/migrate/20260503090000_create_core_ledger_tables.rb`

- [ ] **Step 1: Write failing model constraint tests**

Create `test/models/account_test.rb`:

```ruby
require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "belongs to a user" do
    user = create(:user)
    account = Account.create!(
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

    assert_equal user, account.user
  end

  test "database rejects an account without an owner" do
    account = Account.create!(
      user: create(:user),
      name: "Cash",
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: 0,
      display_order: 1
    )

    error = assert_raises(ActiveRecord::NotNullViolation) do
      account.update_column(:user_id, nil)
    end

    assert_match(/user_id/i, error.message)
  end
end
```

Create `test/models/transaction_test.rb`:

```ruby
require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  test "transfer transactions require a destination account" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    destination_account = create_account(user: user, name: "Savings")

    transaction = Transaction.create!(
      user: user,
      account: account,
      destination_account: destination_account,
      transaction_kind: :transfer,
      transacted_at: Time.zone.parse("2026-05-03 09:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1000,
      destination_amount_cents: 1000
    )

    error = assert_raises(ActiveRecord::StatementInvalid) do
      transaction.update_column(:destination_account_id, nil)
    end

    assert_match(/transactions_transfer_destination_required/i, error.message)
  end

  private

  def create_account(user:, name:)
    Account.create!(
      user: user,
      name: name,
      account_category: :checking_account,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "2563EB",
      currency_code: "USD",
      balance_cents: 0,
      display_order: 1
    )
  end
end
```

- [ ] **Step 2: Run model tests to verify RED**

Run:

```bash
bin/rails test test/models/account_test.rb test/models/transaction_test.rb
```

Expected: FAIL with `uninitialized constant Account`.

- [ ] **Step 3: Add the migration**

Create `db/migrate/20260503090000_create_core_ledger_tables.rb`:

```ruby
class CreateCoreLedgerTables < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts, comment: "User-owned ledger accounts" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this account"
      t.references :parent_account, null: true, foreign_key: { to_table: :accounts }, index: true, comment: "Parent account for two-level account hierarchies"
      t.integer :account_category, null: false, comment: "Account category code from ezBookkeeping"
      t.integer :account_structure, null: false, comment: "Account structure code: single or multi-sub-account"
      t.text :name, null: false, comment: "Human-readable account name"
      t.integer :display_order, null: false, default: 0, comment: "User-controlled display order"
      t.integer :icon_key, null: false, comment: "Icon identifier from the account icon catalog"
      t.text :color_hex, null: false, comment: "Six-character RGB hex color without #"
      t.text :currency_code, null: false, comment: "ISO 4217 currency code"
      t.integer :balance_cents, null: false, default: 0, comment: "Current account balance in cents"
      t.text :comment, null: false, default: "", comment: "Optional user note"
      t.boolean :hidden, null: false, default: false, comment: "Whether the account is hidden in normal lists"
      t.datetime :discarded_at, null: true, comment: "Soft deletion timestamp"
      t.timestamps null: false
    end

    add_index :accounts, :discarded_at
    add_index :accounts, [ :user_id, :parent_account_id, :display_order ], name: "index_accounts_on_owner_parent_order"
    add_check_constraint :accounts, "account_category IN (1,2,3,4,5,6,7,8,9)", name: "accounts_category_valid"
    add_check_constraint :accounts, "account_structure IN (1,2)", name: "accounts_structure_valid"
    add_check_constraint :accounts, "char_length(color_hex) = 6", name: "accounts_color_hex_length"
    add_check_constraint :accounts, "char_length(currency_code) = 3", name: "accounts_currency_code_length"
    add_check_constraint :accounts, "parent_account_id IS NULL OR parent_account_id <> id", name: "accounts_parent_not_self"

    create_table :transactions, comment: "User-owned ledger transactions" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this transaction"
      t.references :account, null: false, foreign_key: true, index: true, comment: "Source account affected by this transaction"
      t.references :destination_account, null: true, foreign_key: { to_table: :accounts }, index: true, comment: "Destination account for transfers"
      t.integer :transaction_kind, null: false, comment: "Transaction kind code: balance adjustment, income, expense, transfer"
      t.datetime :transacted_at, null: false, comment: "User-entered transaction timestamp"
      t.integer :timezone_utc_offset_minutes, null: false, default: 0, comment: "User timezone offset at transaction time"
      t.integer :source_amount_cents, null: false, comment: "Source account amount or balance adjustment delta in cents"
      t.integer :destination_amount_cents, null: false, default: 0, comment: "Destination account amount for transfers in cents"
      t.boolean :hide_amount, null: false, default: false, comment: "Whether amount should be hidden in normal UI"
      t.text :comment, null: false, default: "", comment: "Optional user note"
      t.datetime :discarded_at, null: true, comment: "Soft deletion timestamp"
      t.timestamps null: false
    end

    add_index :transactions, :discarded_at
    add_index :transactions, [ :user_id, :transacted_at ], name: "index_transactions_on_owner_time"
    add_check_constraint :transactions, "transaction_kind IN (1,2,3,4)", name: "transactions_kind_valid"
    add_check_constraint :transactions, "source_amount_cents BETWEEN -99999999999 AND 99999999999", name: "transactions_source_amount_range"
    add_check_constraint :transactions, "destination_amount_cents BETWEEN -99999999999 AND 99999999999", name: "transactions_destination_amount_range"
    add_check_constraint :transactions, "transaction_kind = 4 OR destination_account_id IS NULL", name: "transactions_non_transfer_has_no_destination"
    add_check_constraint :transactions, "transaction_kind <> 4 OR destination_account_id IS NOT NULL", name: "transactions_transfer_destination_required"
    add_check_constraint :transactions, "destination_account_id IS NULL OR destination_account_id <> account_id", name: "transactions_destination_differs_from_source"
  end
end
```

- [ ] **Step 4: Add temporary empty models so migration tests can run**

Create `app/models/account.rb`:

```ruby
class Account < ApplicationRecord
end
```

Create `app/models/transaction.rb`:

```ruby
class Transaction < ApplicationRecord
end
```

- [ ] **Step 5: Run migrations**

Run:

```bash
bin/rails db:migrate
bin/rails db:migrate RAILS_ENV=test
```

Expected: both commands complete and `db/structure.sql` gains `accounts` and `transactions`.

- [ ] **Step 6: Run model tests to verify the next RED state**

Run:

```bash
bin/rails test test/models/account_test.rb test/models/transaction_test.rb
```

Expected: FAIL with enum or association methods missing, such as `NoMethodError: undefined method 'account_category='` or `Association named 'user' was not found`.

## Task 5: Account And Transaction Models

**Files:**
- Modify: `app/models/account.rb`
- Modify: `app/models/transaction.rb`
- Modify: `app/models/user.rb`
- Modify: `test/models/account_test.rb`
- Modify: `test/models/transaction_test.rb`

- [ ] **Step 1: Implement models and associations**

Replace `app/models/account.rb` with:

```ruby
class Account < ApplicationRecord
  include Discard::Model

  has_prefix_id :acct

  belongs_to :user
  belongs_to :parent_account, class_name: "Account", optional: true
  has_many :sub_accounts, class_name: "Account", foreign_key: :parent_account_id, dependent: :restrict_with_error, inverse_of: :parent_account
  has_many :transactions, dependent: :restrict_with_error

  enum :account_category, {
    cash: 1,
    checking_account: 2,
    credit_card: 3,
    virtual: 4,
    debt: 5,
    receivables: 6,
    investment: 7,
    savings_account: 8,
    certificate_of_deposit: 9
  }

  enum :account_structure, {
    single_account: 1,
    multi_sub_accounts: 2
  }

  normalizes :name, with: ->(name) { name.to_s.strip }
  normalizes :color_hex, with: ->(color) { color.to_s.delete_prefix("#").upcase }
  normalizes :currency_code, with: ->(currency) { currency.to_s.upcase }
  normalizes :comment, with: ->(comment) { comment.to_s.strip }

  validates :name, presence: true
  validates :icon_key, numericality: { only_integer: true, greater_than: 0 }
  validates :color_hex, format: { with: /\A\h{6}\z/ }
  validates :currency_code, format: { with: /\A[A-Z]{3}\z/ }
end
```

Replace `app/models/transaction.rb` with:

```ruby
class Transaction < ApplicationRecord
  include Discard::Model

  has_prefix_id :txn

  belongs_to :user
  belongs_to :account
  belongs_to :destination_account, class_name: "Account", optional: true

  enum :transaction_kind, {
    balance_adjustment: 1,
    income: 2,
    expense: 3,
    transfer: 4
  }

  normalizes :comment, with: ->(comment) { comment.to_s.strip }

  validates :transacted_at, presence: true
  validates :source_amount_cents, numericality: { only_integer: true }
  validates :destination_amount_cents, numericality: { only_integer: true }
  validates :destination_account, presence: true, if: :transfer?
end
```

Modify `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  include Users::Authenticatable, Users::Profile, Users::SoftDelete

  has_many :accounts, dependent: :restrict_with_error
  has_many :transactions, dependent: :restrict_with_error
end
```

- [ ] **Step 2: Add normalization coverage**

Append this test to `test/models/account_test.rb`:

```ruby
test "normalizes color and currency fields" do
  account = Account.create!(
    user: create(:user),
    name: "  Cash  ",
    account_category: :cash,
    account_structure: :single_account,
    icon_key: 1,
    color_hex: "#22c55e",
    currency_code: "usd",
    balance_cents: 0,
    display_order: 1
  )

  assert_equal "Cash", account.name
  assert_equal "22C55E", account.color_hex
  assert_equal "USD", account.currency_code
end
```

- [ ] **Step 3: Run model tests to verify GREEN**

Run:

```bash
bin/rails test test/models/account_test.rb test/models/transaction_test.rb
```

Expected: PASS.

- [ ] **Step 4: Commit ledger tables and models**

Run:

```bash
git add db/migrate/20260503090000_create_core_ledger_tables.rb db/structure.sql app/models/account.rb app/models/transaction.rb app/models/user.rb test/models/account_test.rb test/models/transaction_test.rb
git commit -m "feat: add core ledger account tables"
```

## Task 6: AccountCreator Service

**Files:**
- Create: `test/services/account_creator_test.rb`
- Create: `app/services/account_creator.rb`

- [ ] **Step 1: Write failing service tests**

Create `test/services/account_creator_test.rb`:

```ruby
require "test_helper"

class AccountCreatorTest < ActiveSupport::TestCase
  test "creates an account with an opening balance transaction" do
    user = create(:user)

    result = AccountCreator.new.create_account(
      user: user,
      attributes: account_attributes(name: "Cash"),
      opening_balance_cents: 12_345
    )

    assert_predicate result, :created?
    account = result.account
    assert_equal 12_345, account.balance_cents

    transaction = user.transactions.sole
    assert_predicate transaction, :balance_adjustment?
    assert_equal account, transaction.account
    assert_equal 12_345, transaction.source_amount_cents
  end

  test "creates no opening balance transaction for a zero balance" do
    user = create(:user)

    result = AccountCreator.new.create_account(
      user: user,
      attributes: account_attributes(name: "Cash"),
      opening_balance_cents: 0
    )

    assert_predicate result, :created?
    assert_empty user.transactions
  end

  test "returns account errors for invalid attributes" do
    user = create(:user)

    result = AccountCreator.new.create_account(
      user: user,
      attributes: account_attributes(name: ""),
      opening_balance_cents: 0
    )

    refute_predicate result, :created?
    assert_includes result.account.errors[:name], "can't be blank"
  end

  private

  def account_attributes(name:)
    {
      name: name,
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      display_order: 1,
      comment: "Wallet"
    }
  end
end
```

- [ ] **Step 2: Run service test to verify RED**

Run:

```bash
bin/rails test test/services/account_creator_test.rb
```

Expected: FAIL with `uninitialized constant AccountCreator`.

- [ ] **Step 3: Implement AccountCreator**

Create `app/services/account_creator.rb`:

```ruby
class AccountCreator
  def create_account(user:, attributes:, opening_balance_cents:)
    account = user.accounts.build(attributes.merge(balance_cents: opening_balance_cents))

    unless account.valid?
      return Result.new(created: false, account: account)
    end

    ActiveRecord::Base.transaction do
      account.save!
      create_opening_balance_transaction(account, opening_balance_cents) if opening_balance_cents != 0
    end

    Result.new(created: true, account: account)
  end

  private

  def create_opening_balance_transaction(account, opening_balance_cents)
    account.user.transactions.create!(
      account: account,
      transaction_kind: :balance_adjustment,
      transacted_at: Time.current,
      timezone_utc_offset_minutes: 0,
      source_amount_cents: opening_balance_cents,
      destination_amount_cents: 0
    )
  end

  class Result
    attr_reader :account

    def initialize(created:, account:)
      @created = created
      @account = account
    end

    def created? = @created
  end
end
```

- [ ] **Step 4: Run service test to verify GREEN**

Run:

```bash
bin/rails test test/services/account_creator_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit the service**

Run:

```bash
git add app/services/account_creator.rb test/services/account_creator_test.rb
git commit -m "feat: create accounts with opening balances"
```

## Task 7: Account Policy And Controller Boundary Tests

**Files:**
- Create: `app/policies/account_policy.rb`
- Create: `test/integration/accounts_test.rb`

- [ ] **Step 1: Write failing integration tests**

Create `test/integration/accounts_test.rb`:

```ruby
require "test_helper"

class AccountsTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get accounts_path

    assert_redirected_to new_user_session_path
  end

  test "lists only current user accounts" do
    user = create(:user)
    other_user = create(:user)
    own_account = create_account(user: user, name: "Checking")
    create_account(user: other_user, name: "Other Checking")

    sign_in user
    get accounts_path

    assert_response :success
    assert_select "h1", text: /accounts/i
    assert_select "li", text: /#{own_account.name}/i
    assert_select "li", text: /Other Checking/i, count: 0
  end

  test "creates an account for current user" do
    user = create(:user)
    sign_in user

    post accounts_path, params: {
      account: {
        name: "Cash",
        account_category: "cash",
        account_structure: "single_account",
        icon_key: "1",
        color_hex: "22C55E",
        currency_code: "USD",
        opening_balance_cents: "1234",
        comment: "Wallet"
      }
    }

    account = user.accounts.sole
    assert_redirected_to accounts_path
    assert_equal "Cash", account.name
    assert_equal 1234, account.balance_cents
  end

  private

  def create_account(user:, name:)
    Account.create!(
      user: user,
      name: name,
      account_category: :checking_account,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "2563EB",
      currency_code: "USD",
      balance_cents: 0,
      display_order: 1
    )
  end
end
```

- [ ] **Step 2: Run integration test to verify RED**

Run:

```bash
bin/rails test test/integration/accounts_test.rb
```

Expected: FAIL with `undefined local variable or method 'accounts_path'`.

- [ ] **Step 3: Add the account policy**

Create `app/policies/account_policy.rb`:

```ruby
class AccountPolicy < ApplicationPolicy
  def index? = user.present?
  def new? = create?
  def create? = user.present?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
```

## Task 8: Accounts Routes, Controller, And Views

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/accounts_controller.rb`
- Create: `app/views/accounts/index.html.erb`
- Create: `app/views/accounts/new.html.erb`
- Create: `app/views/accounts/_form.html.erb`
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Add canonical account routes**

Modify `config/routes.rb` so the root and account routes are:

```ruby
  resources :accounts, only: [ :index, :new, :create ]

  # Defines the root path route ("/")
  root "home#show"
```

- [ ] **Step 2: Add AccountsController**

Create `app/controllers/accounts_controller.rb`:

```ruby
class AccountsController < ApplicationController
  before_action :authenticate_user!

  # GET /accounts
  def index
    authorize Account
    @accounts = policy_scope(Account).kept.where(parent_account_id: nil).order(:display_order, :name)
  end

  # GET /accounts/new
  def new
    @account = current_user.accounts.build(default_account_attributes)
    authorize @account
  end

  # POST /accounts
  def create
    @account = current_user.accounts.build(account_attributes)
    authorize @account

    result = AccountCreator.new.create_account(
      user: current_user,
      attributes: account_attributes,
      opening_balance_cents: opening_balance_cents
    )

    if result.created?
      redirect_to accounts_path, notice: "Account created."
    else
      @account = result.account
      render :new, status: :unprocessable_content
    end
  end

  private

  def account_attributes
    account_params.except(:opening_balance_cents).merge(display_order: next_display_order)
  end

  def account_params
    params.expect(account: [
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

  def default_account_attributes
    {
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: "USD",
      balance_cents: 0,
      display_order: next_display_order
    }
  end
end
```

- [ ] **Step 3: Add accounts index view**

Create `app/views/accounts/index.html.erb`:

```erb
<% content_for :title, "Accounts" %>

<section class="flex flex-col gap-6">
  <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
    <div>
      <p class="text-sm font-medium uppercase tracking-wide text-body-subtle">Ledger</p>
      <h1 class="mt-1 text-3xl font-semibold tracking-tight text-heading">Accounts</h1>
      <p class="mt-2 max-w-2xl text-sm text-body">Create the accounts that transactions will update as the Rails rewrite grows.</p>
    </div>

    <%= render(ButtonComponent.new(href: new_account_path)) { "New account" } %>
  </div>

  <% if @accounts.any? %>
    <ul class="grid gap-4 md:grid-cols-2">
      <% @accounts.each do |account| %>
        <li id="<%= dom_id(account) %>" class="bg-neutral-primary-soft border border-default rounded-base p-5 shadow-xs">
          <div class="flex items-start justify-between gap-4">
            <div>
              <h2 class="text-lg font-semibold text-heading"><%= account.name %></h2>
              <p class="mt-1 text-sm text-body-subtle"><%= account.currency_code %> · <%= account.account_category.humanize %></p>
            </div>
            <span class="rounded-base bg-neutral-secondary-medium px-3 py-1 text-sm font-medium text-heading"><%= number_to_currency(account.balance_cents / 100.0, unit: "") %></span>
          </div>

          <% if account.comment.present? %>
            <p class="mt-4 text-sm text-body"><%= account.comment %></p>
          <% end %>
        </li>
      <% end %>
    </ul>
  <% else %>
    <div class="bg-neutral-primary-soft border border-default rounded-base p-8 text-center shadow-xs">
      <h2 class="text-xl font-semibold text-heading">No accounts yet</h2>
      <p class="mx-auto mt-2 max-w-xl text-sm text-body">Start with cash, checking, credit card, or another account you use for daily bookkeeping.</p>
      <div class="mt-5"><%= render(ButtonComponent.new(href: new_account_path)) { "Create first account" } %></div>
    </div>
  <% end %>
</section>
```

- [ ] **Step 4: Add new account view**

Create `app/views/accounts/new.html.erb`:

```erb
<% content_for :title, "New account" %>

<section class="mx-auto w-full max-w-2xl">
  <div class="mb-6">
    <p class="text-sm font-medium uppercase tracking-wide text-body-subtle">Ledger</p>
    <h1 class="mt-1 text-3xl font-semibold tracking-tight text-heading">New account</h1>
    <p class="mt-2 text-sm text-body">Add an account and optional opening balance.</p>
  </div>

  <%= render "form", account: @account %>
</section>
```

- [ ] **Step 5: Add account form partial**

Create `app/views/accounts/_form.html.erb`:

```erb
<%# locals: (account:) %>

<%= form_with model: account, class: "bg-neutral-primary-soft border border-default rounded-base p-6 shadow-xs" do |form| %>
  <% if account.errors.any? %>
    <div class="mb-5 rounded-base border border-danger bg-neutral-primary p-4 text-sm text-danger">
      <p class="font-medium">Account could not be saved.</p>
      <ul class="mt-2 list-disc ps-5">
        <% account.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <%= render FormField::InputComponent.new(form: form, field: :name, label: "Name", autofocus: true, required: true) %>

  <div class="mb-4 grid gap-4 sm:grid-cols-2">
    <div>
      <%= form.label :account_category, "Category", class: "block mb-2 text-sm font-medium text-heading" %>
      <%= form.select :account_category, Account.account_categories.keys.map { |key| [ key.humanize, key ] }, {}, class: "bg-neutral-secondary-medium border border-default-medium text-heading text-sm rounded-base focus:ring-brand focus:border-brand block w-full px-3 py-2.5 shadow-xs" %>
    </div>

    <div>
      <%= form.label :account_structure, "Structure", class: "block mb-2 text-sm font-medium text-heading" %>
      <%= form.select :account_structure, Account.account_structures.keys.map { |key| [ key.humanize, key ] }, {}, class: "bg-neutral-secondary-medium border border-default-medium text-heading text-sm rounded-base focus:ring-brand focus:border-brand block w-full px-3 py-2.5 shadow-xs" %>
    </div>
  </div>

  <div class="mb-4 grid gap-4 sm:grid-cols-3">
    <div>
      <%= form.label :icon_key, "Icon", class: "block mb-2 text-sm font-medium text-heading" %>
      <%= form.number_field :icon_key, min: 1, required: true, class: "bg-neutral-secondary-medium border border-default-medium text-heading text-sm rounded-base focus:ring-brand focus:border-brand block w-full px-3 py-2.5 shadow-xs placeholder:text-body" %>
    </div>
    <%= render FormField::InputComponent.new(form: form, field: :color_hex, label: "Color", placeholder: "22C55E", required: true) %>
    <%= render FormField::InputComponent.new(form: form, field: :currency_code, label: "Currency", placeholder: "USD", required: true) %>
  </div>

  <div class="mb-4">
    <%= label_tag "account_opening_balance_cents", "Opening balance cents", class: "block mb-2 text-sm font-medium text-heading" %>
    <%= number_field_tag "account[opening_balance_cents]", account.balance_cents, id: "account_opening_balance_cents", class: "bg-neutral-secondary-medium border border-default-medium text-heading text-sm rounded-base focus:ring-brand focus:border-brand block w-full px-3 py-2.5 shadow-xs placeholder:text-body" %>
  </div>

  <%= render FormField::InputComponent.new(form: form, field: :comment, label: "Comment", type: :textarea) %>

  <div class="flex items-center justify-end gap-3">
    <%= render(ButtonComponent.new(variant: :secondary, href: accounts_path)) { "Cancel" } %>
    <%= render(ButtonComponent.new(type: :submit, data: { turbo_submits_with: "Saving..." })) { "Create account" } %>
  </div>
<% end %>
```

- [ ] **Step 6: Add signed-in account navigation**

In `app/views/layouts/application.html.erb`, add this link inside the `if user_signed_in?` branch before the user email/name span:

```erb
<%= link_to "Accounts", accounts_path, class: "text-sm font-medium text-body hover:text-heading" %>
```

- [ ] **Step 7: Run integration test to verify GREEN**

Run:

```bash
bin/rails test test/integration/accounts_test.rb
```

Expected: PASS.

- [ ] **Step 8: Run route inspection**

Run:

```bash
bin/rails routes -g accounts
```

Expected: output includes `accounts GET /accounts(.:format) accounts#index`, `new_account GET /accounts/new(.:format) accounts#new`, and `POST /accounts(.:format) accounts#create`.

- [ ] **Step 9: Commit account UI**

Run:

```bash
git add app/policies/account_policy.rb test/integration/accounts_test.rb config/routes.rb app/controllers/accounts_controller.rb app/views/accounts/index.html.erb app/views/accounts/new.html.erb app/views/accounts/_form.html.erb app/views/layouts/application.html.erb
git commit -m "feat: add account creation UI"
```

## Task 9: Slice Verification

**Files:**
- Verify: all files changed in Tasks 1-8

- [ ] **Step 1: Run targeted tests**

Run:

```bash
bin/rails test test/lib/ezbookkeeping/source_inventory_test.rb test/models/account_test.rb test/models/transaction_test.rb test/services/account_creator_test.rb test/integration/accounts_test.rb
```

Expected: PASS.

- [ ] **Step 2: Run full model/controller suite**

Run:

```bash
bin/rails test
```

Expected: PASS.

- [ ] **Step 3: Run Ruby lint**

Run:

```bash
bin/rubocop
```

Expected: PASS.

- [ ] **Step 4: Run ERB lint for changed views**

Run:

```bash
bundle exec erb_lint app/views/accounts app/views/layouts/application.html.erb
```

Expected: PASS.

- [ ] **Step 5: Commit any lint-only fixes**

If lint changed files, run:

```bash
git add app test lib config db docs Gemfile Gemfile.lock
git commit -m "style: clean account slice"
```

Expected: commit is created only if lint produced edits.

## Self-Review Checklist

- Spec coverage: This plan implements Phase 0 inventory/docs and starts Phase 1 with accounts plus opening-balance transactions. Categories, tags, full transaction recording, dashboard, imports, reports, settings, security, attachments, schedules, API, AI, and MCP remain intentionally outside this first implementation plan.
- Placeholder scan: no task asks the implementer to invent unnamed behavior; every new file has concrete content.
- Type consistency: account fields use `account_category`, `account_structure`, `balance_cents`; transaction fields use `transaction_kind`, `source_amount_cents`, and `destination_amount_cents` across migration, models, services, views, and tests.
