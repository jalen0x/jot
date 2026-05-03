# ezBookkeeping Scheduled Transaction Job Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire `ScheduledTransactionCreator` into Solid Queue so due scheduled templates are processed automatically by a recurring job.

**Architecture:** Add one thin Active Job that delegates directly to `ScheduledTransactionCreator`. The job does not rescue or discard domain failures; the creator already prevents duplicate scheduled transactions with `last_generated_on` and row locks, so retries are safe. Static recurring configuration lives in `config/recurring.yml` for production only.

**Tech Stack:** Rails 8.1, Active Job, Solid Queue recurring tasks, Minitest job tests.

---

## File Structure

- Create `app/jobs/scheduled_transaction_creation_job.rb`: no-argument job that delegates to `ScheduledTransactionCreator#create_due_transactions` with `Time.current`.
- Create `test/jobs/scheduled_transaction_creation_job_test.rb`: job boundary tests for enqueue/dequeue/perform wiring, failure surfacing, and recurring config presence.
- Modify `config/recurring.yml`: add production static recurring task for scheduled transaction creation.

---

### Task 1: Add job boundary tests

**Files:**
- Create: `test/jobs/scheduled_transaction_creation_job_test.rb`

- [ ] **Step 1: Write failing job tests**

Create `test/jobs/scheduled_transaction_creation_job_test.rb`:

```ruby
require "test_helper"

class ScheduledTransactionCreationJobTest < ActiveJob::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "creates due scheduled transactions through the job adapter" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :expense)
    template = create_template(
      user: user,
      account: account,
      transaction_category: category,
      scheduled_at_minutes: 60,
      timezone_utc_offset_minutes: 0
    )

    travel_to Time.utc(2026, 5, 3, 2, 0) do
      perform_enqueued_jobs do
        ScheduledTransactionCreationJob.perform_later
      end
    end

    assert_equal 4_000, account.reload.balance_cents
    assert_equal Date.new(2026, 5, 3), template.reload.last_generated_on
    assert_equal 1, user.transactions.expense.count
  end

  test "surfaces creator failures for Solid Queue retry visibility" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 5_000)
    mismatched_category = create_category(user: user, category_type: :expense)
    create_template(
      user: user,
      account: account,
      transaction_category: mismatched_category,
      transaction_kind: :income,
      scheduled_at_minutes: 60,
      timezone_utc_offset_minutes: 0
    )

    travel_to Time.utc(2026, 5, 3, 2, 0) do
      assert_raises(ActiveRecord::RecordInvalid) do
        ScheduledTransactionCreationJob.perform_now
      end
    end

    assert_equal 5_000, account.reload.balance_cents
  end

  test "production recurring config schedules the job" do
    config = YAML.load_file(Rails.root.join("config/recurring.yml"))
    task = config.fetch("production").fetch("create_scheduled_transactions")

    assert_equal "ScheduledTransactionCreationJob", task.fetch("class")
    assert_equal "every 5 minutes", task.fetch("schedule")
  end

  private

  def create_template(user:, account:, transaction_category:, scheduled_at_minutes:, timezone_utc_offset_minutes:, transaction_kind: :expense)
    TransactionTemplate.create!(
      user: user,
      account: account,
      transaction_category: transaction_category,
      template_kind: :scheduled,
      transaction_kind: transaction_kind,
      name: "Scheduled template",
      source_amount_cents: 1_000,
      destination_amount_cents: 0,
      schedule_frequency: :daily,
      schedule_rule: "0",
      scheduled_at_minutes: scheduled_at_minutes,
      timezone_utc_offset_minutes: timezone_utc_offset_minutes,
      display_order: 1
    )
  end

  def create_account(user:, name: "Cash", balance_cents: 0, currency_code: "USD")
    Account.create!(
      user: user,
      name: name,
      account_category: :cash,
      account_structure: :single_account,
      icon_key: 1,
      color_hex: "22C55E",
      currency_code: currency_code,
      balance_cents: balance_cents,
      display_order: 1
    )
  end

  def create_category(user:, category_type:)
    TransactionCategory.create!(
      user: user,
      name: category_type.to_s.humanize,
      category_type: category_type,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end
end
```

- [ ] **Step 2: Run tests RED**

Run: `mise exec -- bin/rails test test/jobs/scheduled_transaction_creation_job_test.rb`

Expected: FAIL because `ScheduledTransactionCreationJob` and the recurring task are missing.

---

### Task 2: Add the job and recurring schedule

**Files:**
- Create: `app/jobs/scheduled_transaction_creation_job.rb`
- Modify: `config/recurring.yml`

- [ ] **Step 1: Add the thin job**

Create `app/jobs/scheduled_transaction_creation_job.rb`:

```ruby
class ScheduledTransactionCreationJob < ApplicationJob
  def perform
    ScheduledTransactionCreator.new.create_due_transactions(current_time: Time.current)
  end
end
```

Do not add `discard_on`, broad rescue, or `retry_on`. Domain failures must surface to Solid Queue.

- [ ] **Step 2: Add production recurring config**

Modify `config/recurring.yml` under `production:`:

```yaml
  create_scheduled_transactions:
    class: ScheduledTransactionCreationJob
    schedule: every 5 minutes
```

Keep the existing `clear_solid_queue_finished_jobs` task unchanged.

- [ ] **Step 3: Run job tests GREEN**

Run: `mise exec -- bin/rails test test/jobs/scheduled_transaction_creation_job_test.rb`

Expected: PASS.

---

### Task 3: Verify and commit the slice

**Files:**
- `app/jobs/scheduled_transaction_creation_job.rb`
- `test/jobs/scheduled_transaction_creation_job_test.rb`
- `config/recurring.yml`

- [ ] **Step 1: Run focused tests**

Run: `mise exec -- bin/rails test test/jobs/scheduled_transaction_creation_job_test.rb test/services/scheduled_transaction_creator_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full Rails tests**

Run: `mise exec -- bin/rails test`

Expected: PASS.

- [ ] **Step 3: Run RuboCop for touched files**

Run: `mise exec -- bin/rubocop app/jobs/scheduled_transaction_creation_job.rb test/jobs/scheduled_transaction_creation_job_test.rb`

Expected: PASS.

- [ ] **Step 4: Commit implementation**

Run:

```bash
git add app/jobs/scheduled_transaction_creation_job.rb test/jobs/scheduled_transaction_creation_job_test.rb config/recurring.yml
git commit --no-gpg-sign -m "feat: schedule transaction creation job"
```

Expected: commit succeeds and working tree is clean.

---

## Self-Review

- Spec coverage: completes the Phase 7 automation hook by running `ScheduledTransactionCreator` from Solid Queue recurring configuration.
- Scope control: no UI, template CRUD, API, or schedule editor in this slice.
- Placeholder scan: no TODO/TBD placeholders remain.
- Testing fit: job tests cover Active Job boundary and failure visibility; service tests continue to own detailed schedule behavior.
