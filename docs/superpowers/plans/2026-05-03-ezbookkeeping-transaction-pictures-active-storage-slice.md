# ezBookkeeping Transaction Pictures Active Storage Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Active Storage foundation for transaction pictures, including upload during transaction creation, index display, and purge-on-delete cleanup.

**Architecture:** Use Rails Active Storage directly on `Transaction` with `has_many_attached :pictures`. Creation stays centralized in `TransactionRecorder`; the HTML `TransactionsController` passes uploaded files to the service. `TransactionReversal` purges attached files before discarding the transaction, satisfying the project soft-delete rule for attached files. This slice does not add image processing, preview thumbnails, direct uploads, API uploads, or cloud provider changes.

**Tech Stack:** Rails 8.1, Active Storage, PostgreSQL `structure.sql`, Minitest integration/service tests, existing R2 storage config.

---

## File Structure

- Add Active Storage migrations: generated tables for blobs, attachments, and variant records.
- Modify `app/models/transaction.rb`: add `has_many_attached :pictures` and expose picture filenames in `as_json` only if needed later; no API upload in this slice.
- Modify `app/services/transaction_recorder.rb`: accept `picture_files: []` and attach after transaction save.
- Modify `app/services/transaction_reversal.rb`: purge attached pictures before `discard!`.
- Modify `app/controllers/transactions_controller.rb`: permit `pictures: []` and pass them to recorder.
- Modify `app/views/transactions/_form.html.erb`: add multiple file input for pictures.
- Modify `app/views/transactions/index.html.erb`: display attached picture filenames.
- Add `test/fixtures/files/receipt.txt`: small upload fixture.
- Modify `test/services/transaction_reversal_test.rb`: prove attachments are purged on delete.
- Modify `test/integration/transactions_test.rb`: prove HTML create accepts a picture upload.
- Update `db/structure.sql` by running migrations.

---

### Task 1: Add failing upload and purge tests

**Files:**
- Create: `test/fixtures/files/receipt.txt`
- Modify: `test/integration/transactions_test.rb`
- Modify: `test/services/transaction_reversal_test.rb`

- [ ] **Step 1: Add fixture and tests**

Add a tiny fixture `test/fixtures/files/receipt.txt` with `receipt image placeholder`.

Update `TransactionsTest#creates an expense for current user` to submit `pictures: [fixture_file_upload("receipt.txt", "text/plain")]`, then assert:

```ruby
assert_predicate transaction.pictures, :attached?
assert_equal [ "receipt.txt" ], transaction.pictures.map(&:filename).map(&:to_s)
```

Add a `TransactionReversalTest` that attaches `receipt.txt`, deletes the transaction through `TransactionReversal`, and asserts the transaction is discarded and `transaction.pictures` is no longer attached.

- [ ] **Step 2: Run tests RED**

Run: `mise exec -- bin/rails test test/integration/transactions_test.rb test/services/transaction_reversal_test.rb`

Expected: FAIL because Active Storage tables/association and upload handling are missing.

---

### Task 2: Add Active Storage and model/service support

**Files:**
- Create Active Storage migration(s)
- Modify: `db/structure.sql`
- Modify: `app/models/transaction.rb`
- Modify: `app/services/transaction_recorder.rb`
- Modify: `app/services/transaction_reversal.rb`

- [ ] **Step 1: Install Active Storage migrations**

Run `mise exec -- bin/rails active_storage:install` or add the equivalent Rails-generated migration. If the generated timestamp sorts before existing migrations, rename it to the next chronological app timestamp before migrating.

Run: `mise exec -- bin/rails db:migrate`

Expected: `db/structure.sql` includes Active Storage tables.

- [ ] **Step 2: Add attachment association**

In `app/models/transaction.rb` add:

```ruby
has_many_attached :pictures
```

- [ ] **Step 3: Update recorder**

Change `TransactionRecorder#record_transaction` signature to:

```ruby
def record_transaction(user:, attributes:, tag_ids:, picture_files: [])
```

Inside the transaction, after taggings are created and before balance updates, attach files:

```ruby
transaction.pictures.attach(Array(picture_files).reject(&:blank?))
```

Existing callers do not need changes because the argument has a default.

- [ ] **Step 4: Purge on reversal**

In `TransactionReversal`, before `transaction.discard!`, call:

```ruby
transaction.pictures.purge if transaction.pictures.attached?
```

Keep it inside the existing transaction after balance reversal.

---

### Task 3: Wire HTML transaction form

**Files:**
- Modify: `app/controllers/transactions_controller.rb`
- Modify: `app/views/transactions/_form.html.erb`
- Modify: `app/views/transactions/index.html.erb`

- [ ] **Step 1: Permit and pass uploads**

In `TransactionsController`, add `pictures: []` to `transaction_params` and pass `picture_files: picture_files` to `TransactionRecorder`.

Add:

```ruby
def picture_files
  Array(transaction_params[:pictures]).reject(&:blank?)
end
```

- [ ] **Step 2: Add file input**

In `app/views/transactions/_form.html.erb`, add a multiple file input named `transaction[pictures][]` using semantic Flowbite file input classes.

- [ ] **Step 3: Display attached filenames**

In `app/views/transactions/index.html.erb`, when `transaction.pictures.attached?`, render filenames in the transaction card.

- [ ] **Step 4: Run tests GREEN**

Run: `mise exec -- bin/rails test test/integration/transactions_test.rb test/services/transaction_reversal_test.rb`

Expected: PASS.

---

### Task 4: Verify and commit the slice

**Files:**
- All files changed above.

- [ ] **Step 1: Run focused tests**

Run: `mise exec -- bin/rails test test/integration/transactions_test.rb test/services/transaction_recorder_test.rb test/services/transaction_reversal_test.rb test/models/transaction_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run RuboCop for touched Ruby files**

Run: `mise exec -- bin/rubocop app/controllers/transactions_controller.rb app/models/transaction.rb app/services/transaction_recorder.rb app/services/transaction_reversal.rb test/integration/transactions_test.rb test/services/transaction_reversal_test.rb db/migrate/*.active_storage.rb`

Expected: PASS.

- [ ] **Step 4: Run ERB lint for touched views**

Run: `mise exec -- bundle exec erb_lint app/views/transactions/_form.html.erb app/views/transactions/index.html.erb`

Expected: PASS.

- [ ] **Step 5: Commit implementation**

Run:

```bash
git add app/models/transaction.rb app/services/transaction_recorder.rb app/services/transaction_reversal.rb app/controllers/transactions_controller.rb app/views/transactions/_form.html.erb app/views/transactions/index.html.erb test/integration/transactions_test.rb test/services/transaction_reversal_test.rb test/fixtures/files/receipt.txt db/migrate db/structure.sql
git commit --no-gpg-sign -m "feat: add transaction picture attachments"
```

Expected: commit succeeds and working tree is clean.

---

## Self-Review

- Spec coverage: starts Phase 6 transaction pictures with Active Storage upload and purge behavior.
- Scope control: no thumbnails, direct uploads, API uploads, AI receipt recognition, maps, or PWA changes.
- Placeholder scan: no TODO/TBD placeholders remain.
- Testing fit: integration test covers HTTP upload path; service test covers purge-on-soft-delete rule.
