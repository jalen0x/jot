# ezBookkeeping Import Batches Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a minimum CSV import path for the CSV format produced by `DataExport`.

**Architecture:** `ImportBatch` stores a bounded raw CSV snapshot and status. `ImportBatchParserJob` processes the batch asynchronously and calls `TransactionImporter#import_transactions`, which parses rows and records ledger effects through `TransactionRecorder`.

**Tech Stack:** Rails 8.1, PostgreSQL SQL schema, Solid Queue / Active Job, Ruby CSV gem, Devise, Pundit, Minitest, FactoryBot.

---

## File Structure

- `db/migrate/20260503120000_create_import_batches.rb`: import batch status and raw CSV snapshot.
- `app/models/import_batch.rb`: user-owned import state.
- `app/models/user.rb`: `has_many :import_batches`.
- `test/models/import_batch_test.rb`: ownership/status model coverage.
- `app/services/transaction_importer.rb`: parse exported CSV rows and record transactions through `TransactionRecorder`.
- `test/services/transaction_importer_test.rb`: successful import and missing reference coverage.
- `app/jobs/import_batch_parser_job.rb`: async import batch processing.
- `test/jobs/import_batch_parser_job_test.rb`: job success/failure status coverage.
- `app/policies/import_batch_policy.rb`: Pundit authorization and scope.
- `app/controllers/import_batches_controller.rb`: new/create/show boundary.
- `app/views/import_batches/new.html.erb`: raw CSV import form.
- `app/views/import_batches/show.html.erb`: import status page.
- `config/routes.rb`: canonical `resources :import_batches, only: [:new, :create, :show]`.
- `app/views/layouts/application.html.erb`: signed-in Imports nav link.
- `test/integration/import_batches_test.rb`: auth, create/enqueue/process, and user scoping coverage.

## Task 1: ImportBatch Model

- [ ] **Step 1: Write failing model test**

Create `test/models/import_batch_test.rb` with tests for user ownership, name normalization-free raw CSV persistence, and enum status defaults.

- [ ] **Step 2: Run model test to verify RED**

Run `mise exec -- bin/rails test test/models/import_batch_test.rb`.
Expected: FAIL with `uninitialized constant ImportBatch`.

- [ ] **Step 3: Add migration and model**

Create `db/migrate/20260503120000_create_import_batches.rb`:

```ruby
class CreateImportBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :import_batches, comment: "User-owned transaction import batches" do |t|
      t.references :user, null: false, foreign_key: true, index: true, comment: "Owner of this import batch"
      t.integer :status, null: false, default: 0, comment: "Import status code: pending, processing, imported, or failed"
      t.text :source_filename, null: false, default: "", comment: "Original uploaded file name or label"
      t.text :raw_csv, null: false, comment: "Raw CSV snapshot to import"
      t.integer :imported_count, null: false, default: 0, comment: "Number of imported transaction rows"
      t.text :error_message, null: false, default: "", comment: "User-facing import error message"
      t.timestamps null: false
    end

    add_index :import_batches, [ :user_id, :created_at ], name: "index_import_batches_on_owner_created_at"
    add_check_constraint :import_batches, "status IN (0,1,2,3)", name: "import_batches_status_valid"
  end
end
```

Create `app/models/import_batch.rb`:

```ruby
class ImportBatch < ApplicationRecord
  has_prefix_id :imp

  belongs_to :user

  enum :status, {
    pending: 0,
    processing: 1,
    imported: 2,
    failed: 3
  }

  validates :raw_csv, presence: true
end
```

Add to `app/models/user.rb`:

```ruby
  has_many :import_batches, dependent: :restrict_with_error
```

Run migrations for development and test.

- [ ] **Step 4: Run model tests to verify GREEN**

Run `mise exec -- bin/rails test test/models/import_batch_test.rb`.
Expected: PASS.

- [ ] **Step 5: Commit ImportBatch**

Commit with `git commit -m "feat: add import batches"`.

## Task 2: TransactionImporter And Job

- [ ] **Step 1: Write failing importer and job tests**

Create `test/services/transaction_importer_test.rb` covering one successful exported CSV row and one missing account failure.
Create `test/jobs/import_batch_parser_job_test.rb` covering imported and failed statuses.

- [ ] **Step 2: Run tests to verify RED**

Run `mise exec -- bin/rails test test/services/transaction_importer_test.rb test/jobs/import_batch_parser_job_test.rb`.
Expected: FAIL with missing constants.

- [ ] **Step 3: Implement importer and job**

Create `app/services/transaction_importer.rb`:

```ruby
require "csv"

class TransactionImporter
  class ImportError < StandardError; end

  def import_transactions(import_batch:)
    imported_count = 0

    CSV.parse(import_batch.raw_csv, headers: true).each do |row|
      record_row(import_batch.user, row)
      imported_count += 1
    end

    import_batch.update!(status: :imported, imported_count: imported_count, error_message: "")
  rescue CSV::MalformedCSVError => error
    raise ImportError, error.message
  end

  private

  def record_row(user, row)
    account = find_account(user, row.fetch("Account"))
    destination_account = row["Destination Account"].present? ? find_account(user, row["Destination Account"]) : nil
    category = find_category(user, row.fetch("Category"))
    tag_ids = tag_ids(user, row["Tags"])

    result = TransactionRecorder.new.record_transaction(
      user: user,
      attributes: {
        transaction_kind: row.fetch("Type"),
        account_id: account.id.to_s,
        destination_account_id: destination_account&.id.to_s,
        transaction_category_id: category.id.to_s,
        transacted_at: row.fetch("Transacted At"),
        timezone_utc_offset_minutes: "0",
        source_amount_cents: row.fetch("Source Amount Cents"),
        destination_amount_cents: row.fetch("Destination Amount Cents"),
        hide_amount: "0",
        comment: row["Comment"]
      },
      tag_ids: tag_ids
    )

    raise ImportError, result.transaction.errors.full_messages.to_sentence unless result.recorded?
  end

  def find_account(user, name)
    user.accounts.kept.find_by!(name: name)
  rescue ActiveRecord::RecordNotFound
    raise ImportError, "Account not found: #{name}"
  end

  def find_category(user, name)
    user.transaction_categories.kept.find_by!(name: name)
  rescue ActiveRecord::RecordNotFound
    raise ImportError, "Category not found: #{name}"
  end

  def tag_ids(user, value)
    names = value.to_s.split(";").map(&:strip).reject(&:blank?)
    tags = user.transaction_tags.kept.where(name: names).to_a
    found_names = tags.map(&:name)
    missing_names = names - found_names
    raise ImportError, "Tags not found: #{missing_names.to_sentence}" if missing_names.any?

    tags.map { |tag| tag.id.to_s }
  end
end
```

Create `app/jobs/import_batch_parser_job.rb`:

```ruby
class ImportBatchParserJob < ApplicationJob
  discard_on ActiveRecord::RecordNotFound

  def perform(import_batch_id)
    import_batch = ImportBatch.find(import_batch_id)
    import_batch.update!(status: :processing)
    TransactionImporter.new.import_transactions(import_batch: import_batch)
  rescue TransactionImporter::ImportError => error
    import_batch.update!(status: :failed, error_message: error.message)
  end
end
```

- [ ] **Step 4: Run importer/job tests to verify GREEN**

Run `mise exec -- bin/rails test test/services/transaction_importer_test.rb test/jobs/import_batch_parser_job_test.rb`.
Expected: PASS.

- [ ] **Step 5: Commit importer and job**

Commit with `git commit -m "feat: import exported transactions"`.

## Task 3: Import UI

- [ ] **Step 1: Write failing integration tests**

Create `test/integration/import_batches_test.rb` covering auth, create with `perform_enqueued_jobs`, status page, and cross-user 404.

- [ ] **Step 2: Run integration tests to verify RED**

Run `mise exec -- bin/rails test test/integration/import_batches_test.rb`.
Expected: FAIL with missing routes.

- [ ] **Step 3: Implement policy, routes, controller, and views**

Add `resources :import_batches, only: [ :new, :create, :show ]`.
Create `ImportBatchPolicy`, `ImportBatchesController`, `app/views/import_batches/new.html.erb`, `app/views/import_batches/show.html.erb`, and an Imports nav link.

- [ ] **Step 4: Run integration tests to verify GREEN**

Run `mise exec -- bin/rails test test/integration/import_batches_test.rb`.
Expected: PASS.

- [ ] **Step 5: Commit import UI**

Commit with `git commit -m "feat: add transaction import UI"`.

## Task 4: Slice Verification

- [ ] Run targeted tests: `mise exec -- bin/rails test test/models/import_batch_test.rb test/services/transaction_importer_test.rb test/jobs/import_batch_parser_job_test.rb test/integration/import_batches_test.rb`
- [ ] Run full tests: `mise exec -- bin/rails test`
- [ ] Run Ruby lint: `mise exec -- bin/rubocop`
- [ ] Run ERB lint: `mise exec -- bundle exec erb_lint app/views/import_batches app/views/layouts/application.html.erb`
- [ ] Commit lint-only fixes if needed.

## Self-Review Checklist

- Spec coverage: implements Phase 3 minimum import for the app's own exported CSV format. Other source formats, preview screens, import batches with uploaded files, async progress UI, and data clearing remain later Phase 3 slices.
- Placeholder scan: tasks define files, commands, and concrete implementations for the critical service/job path.
- Type consistency: import headers match `DataExport::HEADERS`.
