require "test_helper"

class ScheduledTransactionCreatorTest < ActiveSupport::TestCase
  test "creates a due daily scheduled transaction once for the local date" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :expense)
    tag = create_tag(user: user, name: "Rent")
    template = create_template(
      user: user,
      account: account,
      transaction_category: category,
      schedule_frequency: :daily,
      schedule_rule: "0",
      scheduled_at_minutes: 9 * 60,
      timezone_utc_offset_minutes: 480,
      source_amount_cents: 1_200,
      comment: "  Monthly rent  ",
      transaction_tags: [ tag ]
    )

    result = ScheduledTransactionCreator.new.create_due_transactions(current_time: Time.utc(2026, 5, 3, 1, 30))

    assert_equal 1, result.created_count
    transaction = result.transactions.sole
    assert_predicate transaction, :expense?
    assert_equal account, transaction.account
    assert_equal category, transaction.transaction_category
    assert_equal [ tag ], transaction.transaction_tags.to_a
    assert_equal Time.utc(2026, 5, 3, 1, 0), transaction.transacted_at
    assert_equal 480, transaction.timezone_utc_offset_minutes
    assert_equal 1_200, transaction.source_amount_cents
    assert_equal "Monthly rent", transaction.comment
    assert_equal 3_800, account.reload.balance_cents
    assert_equal Date.new(2026, 5, 3), template.reload.last_generated_on
  end

  test "creates weekly schedules only on selected weekdays" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :expense)
    matching = create_template(
      user: user,
      account: account,
      transaction_category: category,
      schedule_frequency: :weekly,
      schedule_rule: "0",
      scheduled_at_minutes: 60,
      timezone_utc_offset_minutes: 0
    )
    nonmatching = create_template(
      user: user,
      account: account,
      transaction_category: category,
      schedule_frequency: :weekly,
      schedule_rule: "1",
      scheduled_at_minutes: 60,
      timezone_utc_offset_minutes: 0
    )

    result = ScheduledTransactionCreator.new.create_due_transactions(current_time: Time.utc(2026, 5, 3, 2, 0))

    assert_equal 1, result.created_count
    assert_predicate result.transactions.sole, :expense?
    assert_equal 4_000, account.reload.balance_cents
    assert_equal Date.new(2026, 5, 3), matching.reload.last_generated_on
    assert_nil nonmatching.reload.last_generated_on
  end

  test "creates monthly schedules with negative days relative to month end" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :expense)
    template = create_template(
      user: user,
      account: account,
      transaction_category: category,
      schedule_frequency: :monthly,
      schedule_rule: "-1",
      scheduled_at_minutes: 60,
      timezone_utc_offset_minutes: 0
    )

    result = ScheduledTransactionCreator.new.create_due_transactions(current_time: Time.utc(2026, 5, 31, 2, 0))

    assert_equal 1, result.created_count
    assert_equal 4_000, account.reload.balance_cents
    assert_equal Date.new(2026, 5, 31), template.reload.last_generated_on
  end

  test "creates yearly schedules only on selected month and day" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :income)
    template = create_template(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :income,
      schedule_frequency: :yearly,
      schedule_rule: "503",
      scheduled_at_minutes: 60,
      timezone_utc_offset_minutes: 0
    )

    result = ScheduledTransactionCreator.new.create_due_transactions(current_time: Time.utc(2026, 5, 3, 2, 0))

    assert_equal 1, result.created_count
    assert_predicate result.transactions.sole, :income?
    assert_equal 6_000, account.reload.balance_cents
    assert_equal Date.new(2026, 5, 3), template.reload.last_generated_on
  end

  test "skips schedules before scheduled local time and outside date boundaries" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :expense)
    before_time = create_template(
      user: user,
      account: account,
      transaction_category: category,
      schedule_frequency: :daily,
      schedule_rule: "0",
      scheduled_at_minutes: 12 * 60,
      timezone_utc_offset_minutes: 0
    )
    before_start = create_template(
      user: user,
      account: account,
      transaction_category: category,
      schedule_frequency: :daily,
      schedule_rule: "0",
      scheduled_at_minutes: 60,
      timezone_utc_offset_minutes: 0,
      schedule_start_on: Date.new(2026, 5, 4)
    )
    after_end = create_template(
      user: user,
      account: account,
      transaction_category: category,
      schedule_frequency: :daily,
      schedule_rule: "0",
      scheduled_at_minutes: 60,
      timezone_utc_offset_minutes: 0,
      schedule_end_on: Date.new(2026, 5, 2)
    )

    result = ScheduledTransactionCreator.new.create_due_transactions(current_time: Time.utc(2026, 5, 3, 2, 0))

    assert_equal 0, result.created_count
    assert_equal 5_000, account.reload.balance_cents
    assert_nil before_time.reload.last_generated_on
    assert_nil before_start.reload.last_generated_on
    assert_nil after_end.reload.last_generated_on
  end

  test "does not create a duplicate for a template already generated on the local date" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :expense)
    template = create_template(
      user: user,
      account: account,
      transaction_category: category,
      schedule_frequency: :daily,
      schedule_rule: "0",
      scheduled_at_minutes: 60,
      timezone_utc_offset_minutes: 0,
      last_generated_on: Date.new(2026, 5, 3)
    )

    result = ScheduledTransactionCreator.new.create_due_transactions(current_time: Time.utc(2026, 5, 3, 2, 0))

    assert_equal 0, result.created_count
    assert_equal 5_000, account.reload.balance_cents
    assert_equal Date.new(2026, 5, 3), template.reload.last_generated_on
  end

  test "skips disabled and discarded templates" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :expense)
    disabled = create_template(
      user: user,
      account: account,
      transaction_category: category,
      schedule_frequency: :disabled,
      schedule_rule: "",
      scheduled_at_minutes: 60,
      timezone_utc_offset_minutes: 0
    )
    discarded = create_template(
      user: user,
      account: account,
      transaction_category: category,
      schedule_frequency: :daily,
      schedule_rule: "0",
      scheduled_at_minutes: 60,
      timezone_utc_offset_minutes: 0
    )
    discarded.discard

    result = ScheduledTransactionCreator.new.create_due_transactions(current_time: Time.utc(2026, 5, 3, 2, 0))

    assert_equal 0, result.created_count
    assert_equal 5_000, account.reload.balance_cents
    assert_nil disabled.reload.last_generated_on
    assert_nil discarded.reload.last_generated_on
  end

  test "skips templates with invalid schedule values" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 5_000)
    category = create_category(user: user, category_type: :expense)
    template = create_template(
      user: user,
      account: account,
      transaction_category: category,
      schedule_frequency: :daily,
      schedule_rule: "invalid,0",
      scheduled_at_minutes: 60,
      timezone_utc_offset_minutes: 0
    )

    result = ScheduledTransactionCreator.new.create_due_transactions(current_time: Time.utc(2026, 5, 3, 2, 0))

    assert_equal 0, result.created_count
    assert_equal 5_000, account.reload.balance_cents
    assert_nil template.reload.last_generated_on
  end

  test "surfaces recorder validation failures without stamping the template" do
    user = create(:user)
    account = create_account(user: user, balance_cents: 5_000)
    expense_category = create_category(user: user, category_type: :expense)
    template = create_template(
      user: user,
      account: account,
      transaction_category: expense_category,
      transaction_kind: :income,
      schedule_frequency: :daily,
      schedule_rule: "0",
      scheduled_at_minutes: 60,
      timezone_utc_offset_minutes: 0
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      ScheduledTransactionCreator.new.create_due_transactions(current_time: Time.utc(2026, 5, 3, 2, 0))
    end

    assert_nil template.reload.last_generated_on
    assert_equal 5_000, account.reload.balance_cents
  end

  private

  def create_template(user:, account:, transaction_category:, schedule_frequency:, schedule_rule:, scheduled_at_minutes:, timezone_utc_offset_minutes:, source_amount_cents: 1_000, transaction_kind: :expense, destination_account: nil, destination_amount_cents: 0, comment: "Scheduled", transaction_tags: [], schedule_start_on: nil, schedule_end_on: nil, last_generated_on: nil)
    template = TransactionTemplate.create!(
      user: user,
      account: account,
      destination_account: destination_account,
      transaction_category: transaction_category,
      template_kind: :scheduled,
      transaction_kind: transaction_kind,
      name: "Scheduled template",
      source_amount_cents: source_amount_cents,
      destination_amount_cents: destination_amount_cents,
      schedule_frequency: schedule_frequency,
      schedule_rule: schedule_rule,
      schedule_start_on: schedule_start_on,
      schedule_end_on: schedule_end_on,
      scheduled_at_minutes: scheduled_at_minutes,
      timezone_utc_offset_minutes: timezone_utc_offset_minutes,
      last_generated_on: last_generated_on,
      comment: comment,
      display_order: 1
    )

    transaction_tags.each do |tag|
      TransactionTemplateTagging.create!(user: user, transaction_template: template, transaction_tag: tag)
    end

    template
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

  def create_tag(user:, name:)
    TransactionTag.create!(user: user, name: name, display_order: 1)
  end
end
