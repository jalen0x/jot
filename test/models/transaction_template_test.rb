require "test_helper"

class TransactionTemplateTest < ActiveSupport::TestCase
  test "stores a normal transaction template" do
    user = create(:user)
    account = create_account(user: user)
    category = create_category(user: user, category_type: :expense)

    template = TransactionTemplate.create!(
      user: user,
      account: account,
      transaction_category: category,
      template_kind: :normal,
      transaction_kind: :expense,
      name: "  Lunch  ",
      source_amount_cents: 1_200,
      destination_amount_cents: 0,
      hide_amount: true,
      comment: "  Work meal  ",
      display_order: 1
    )

    assert_match(/\Atmpl_/, template.to_param)
    assert_equal "Lunch", template.name
    assert_equal "Work meal", template.comment
    assert_predicate template, :normal?
    assert_predicate template, :expense?
    assert_equal 1_200, template.source_amount_cents
    assert_equal user, template.user
    assert_equal account, template.account
    assert_equal category, template.transaction_category
  end

  test "stores schedule metadata" do
    template = build_template(
      template_kind: :scheduled,
      schedule_frequency: :monthly,
      schedule_rule: "15",
      schedule_start_on: Date.new(2026, 5, 1),
      schedule_end_on: Date.new(2026, 12, 31),
      scheduled_at_minutes: 540,
      timezone_utc_offset_minutes: 480
    )

    assert_predicate template, :scheduled?
    assert_predicate template, :monthly?
    assert_equal "15", template.schedule_rule
    assert_equal Date.new(2026, 5, 1), template.schedule_start_on
    assert_equal Date.new(2026, 12, 31), template.schedule_end_on
    assert_equal 540, template.scheduled_at_minutes
    assert_equal 480, template.timezone_utc_offset_minutes
  end

  test "validates required fields and transfer destination" do
    template = build_template(name: "", transaction_kind: :transfer, destination_account: nil)

    refute_predicate template, :valid?
    assert_includes template.errors[:name], "can't be blank"
    assert_includes template.errors[:destination_account], "can't be blank"
  end

  private

  def build_template(overrides = {})
    user = overrides.delete(:user) || create(:user)
    account = overrides.delete(:account) || create_account(user: user)
    category = overrides.delete(:transaction_category) || create_category(user: user, category_type: overrides[:transaction_kind] || :expense)

    TransactionTemplate.new(
      {
        user: user,
        account: account,
        transaction_category: category,
        template_kind: :normal,
        transaction_kind: :expense,
        name: "Template",
        source_amount_cents: 1_000,
        destination_amount_cents: 0,
        display_order: 1
      }.merge(overrides)
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
