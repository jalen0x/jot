# ezBookkeeping Transaction Template Foundation Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Phase 7 `TransactionTemplate` persistence foundation with explicit schedule columns and tag associations.

**Architecture:** Add Rails-native tables and models only. Templates store transaction shape and optional schedule metadata in explicit columns, not JSONB. Controllers, jobs, template execution, and recurring creation remain later slices. User-owned associations are represented with foreign keys and Rails models; money remains integer cents.

**Tech Stack:** Rails 8.1, PostgreSQL structure.sql, Discard soft delete, prefixed_ids, Minitest model tests.

---

## File Structure

- Create `db/migrate/20260503190000_create_transaction_templates.rb`: `transaction_templates` and `transaction_template_taggings` tables with comments, indexes, FK constraints, and check constraints.
- Create `app/models/transaction_template.rb`: user-owned template model, enums, associations, normalizers, validations, prefixed id.
- Create `app/models/transaction_template_tagging.rb`: join model between templates and tags.
- Modify `app/models/user.rb`: add `has_many :transaction_templates`.
- Modify `app/models/transaction_tag.rb`: add template tagging associations.
- Create `test/models/transaction_template_test.rb`: model coverage.
- Create `test/models/transaction_template_tagging_test.rb`: join ownership coverage.
- Update `db/structure.sql` by running migrations.

---

### Task 1: Add transaction template models and schema

**Files:**
- Create: `test/models/transaction_template_test.rb`
- Create: `test/models/transaction_template_tagging_test.rb`
- Create: `db/migrate/20260503190000_create_transaction_templates.rb`
- Create: `app/models/transaction_template.rb`
- Create: `app/models/transaction_template_tagging.rb`
- Modify: `app/models/user.rb`
- Modify: `app/models/transaction_tag.rb`
- Modify: `db/structure.sql`

- [ ] **Step 1: Write failing model tests**

Add tests proving:

1. A valid normal template belongs to a user/account/category, normalizes name/comment, exposes a `tmpl_` prefixed id, and stores integer cents.
2. A scheduled template can store `schedule_frequency`, `schedule_rule`, `schedule_start_on`, `schedule_end_on`, `scheduled_at_minutes`, and `timezone_utc_offset_minutes`.
3. Template taggings connect a template to user-owned tags.
4. Required fields and schedule enum values are validated.

Use direct model creation. Do not add controller or service tests in this slice.

- [ ] **Step 2: Run model tests RED**

Run: `mise exec -- bin/rails test test/models/transaction_template_test.rb test/models/transaction_template_tagging_test.rb`

Expected: FAIL because constants/tables are missing.

- [ ] **Step 3: Add migration**

Create `db/migrate/20260503190000_create_transaction_templates.rb` with:

- `transaction_templates`: user, account, destination_account, transaction_category, template_kind, transaction_kind, name, display_order, source/destination cents, hide_amount, comment, schedule fields, hidden, discarded_at, timestamps.
- `transaction_template_taggings`: user, transaction_template, transaction_tag, timestamps.
- Explicit `null:` and `comment:` on every column.
- Check constraints for enum values, schedule minutes (`0..1439`), UTC offset (`-720..840`), and non-self account transfer.
- Indexes for owner/template kind/order, schedule lookup, discarded_at, and unique template/tag pair.

- [ ] **Step 4: Add models and associations**

`TransactionTemplate` should include `Discard::Model`, `has_prefix_id :tmpl`, enums:

```ruby
enum :template_kind, { normal: 1, scheduled: 2 }
enum :transaction_kind, { balance_adjustment: 1, income: 2, expense: 3, transfer: 4 }
enum :schedule_frequency, { disabled: 0, weekly: 1, monthly: 2, daily: 3, yearly: 4 }
```

Associations:

- belongs_to `user`
- belongs_to `account`
- belongs_to `destination_account`, optional
- belongs_to `transaction_category`, optional
- has_many `transaction_template_taggings`
- has_many `transaction_tags`, through taggings

Validations:

- `name` presence
- integer numericality for amounts/display/schedule minute/timezone offset
- `transaction_category` present unless `balance_adjustment?`
- `destination_account` present if `transfer?`
- destination account differs from source account when present

- [ ] **Step 5: Run migration and model tests GREEN**

Run:

```bash
mise exec -- bin/rails db:migrate
mise exec -- bin/rails test test/models/transaction_template_test.rb test/models/transaction_template_tagging_test.rb
```

Expected: migration updates `db/structure.sql`; tests PASS.

- [ ] **Step 6: Commit template foundation**

```bash
git add db/migrate/20260503190000_create_transaction_templates.rb db/structure.sql app/models/transaction_template.rb app/models/transaction_template_tagging.rb app/models/user.rb app/models/transaction_tag.rb test/models/transaction_template_test.rb test/models/transaction_template_tagging_test.rb
git commit --no-gpg-sign -m "feat: add transaction template foundation"
```

---

### Task 2: Verify transaction template foundation slice

- [ ] **Step 1: Run focused tests**

Run: `mise exec -- bin/rails test test/models/transaction_template_test.rb test/models/transaction_template_tagging_test.rb test/models/transaction_tag_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run lint for touched files**

Run: `mise exec -- bin/rubocop app/models/transaction_template.rb app/models/transaction_template_tagging.rb app/models/user.rb app/models/transaction_tag.rb test/models/transaction_template_test.rb test/models/transaction_template_tagging_test.rb db/migrate/20260503190000_create_transaction_templates.rb`

Expected: PASS.

- [ ] **Step 4: Check git status**

Run: `git status --short`

Expected: clean working tree.

---

## Self-Review

- Spec coverage: starts Phase 7 with explicit `TransactionTemplate` persistence and tag associations.
- Scope control: does not add UI, controllers, API endpoints, recurring jobs, or transaction generation.
- Placeholder scan: no TODO/TBD placeholders remain.
- Type consistency: money uses integer cents; source `type` is represented as `transaction_kind`, not a reserved `type` column.
