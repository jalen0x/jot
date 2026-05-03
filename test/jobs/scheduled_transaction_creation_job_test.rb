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
