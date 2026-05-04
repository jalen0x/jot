require "test_helper"

class DataStatisticsTest < ActiveSupport::TestCase
  test "counts kept user-owned data for data management" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking")
    savings = create_account(user: user, name: "Savings")
    discarded_account = create_account(user: user, name: "Closed")
    discarded_account.discard!
    category = create_category(user: user, name: "Food", category_type: :expense)
    discarded_category = create_category(user: user, name: "Archived", category_type: :expense)
    discarded_category.discard!
    tag = create_tag(user: user, name: "Meals")
    create_tag(user: user, name: "Travel")
    discarded_tag = create_tag(user: user, name: "Archived")
    discarded_tag.discard!
    transaction = create_transaction(user: user, account: account, category: category, comment: "Lunch")
    transaction.pictures.attach(io: StringIO.new("one"), filename: "one.txt", content_type: "text/plain", identify: false)
    transaction.pictures.attach(io: StringIO.new("two"), filename: "two.txt", content_type: "text/plain", identify: false)
    create_transaction(user: user, account: savings, category: category, comment: "Dinner")
    discarded_transaction = create_transaction(user: user, account: account, category: category, comment: "Archived")
    discarded_transaction.discard!
    InsightExplorer.create!(user: user, name: "Monthly", config: {}, display_order: 1)
    discarded_explorer = InsightExplorer.create!(user: user, name: "Archived", config: {}, display_order: 2)
    discarded_explorer.discard!
    create_template(user: user, account: account, category: category, name: "Lunch", template_kind: :normal, tags: [ tag ])
    create_template(user: user, account: account, category: category, name: "Rent", template_kind: :scheduled, tags: [ tag ])
    discarded_template = create_template(user: user, account: account, category: category, name: "Archived", template_kind: :normal, tags: [])
    discarded_template.discard!
    create_account(user: other_user, name: "Other")
    other_category = create_category(user: other_user, name: "Other Food", category_type: :expense)
    create_tag(user: other_user, name: "Other")
    create_transaction(user: other_user, account: create_account(user: other_user, name: "Other Cash"), category: other_category, comment: "Other")
    InsightExplorer.create!(user: other_user, name: "Other", config: {}, display_order: 1)
    create_template(user: other_user, account: create_account(user: other_user, name: "Other Template Account"), category: other_category, name: "Other Template", template_kind: :scheduled, tags: [])

    statistics = DataStatistics.new.summarize_user_data(user: user)

    assert_equal 2, statistics.account_count
    assert_equal 1, statistics.transaction_category_count
    assert_equal 2, statistics.transaction_tag_count
    assert_equal 2, statistics.transaction_count
    assert_equal 2, statistics.transaction_picture_count
    assert_equal 1, statistics.insight_explorer_count
    assert_equal 1, statistics.transaction_template_count
    assert_equal 1, statistics.scheduled_transaction_count
  end

  private

  def create_account(user:, name:)
    Account.create!(
      user: user,
      name: name,
      account_category: :checking_account,
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

  def create_transaction(user:, account:, category:, comment:)
    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 09:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1_200,
      destination_amount_cents: 0,
      comment: comment
    )
  end

  def create_template(user:, account:, category:, name:, template_kind:, tags:)
    template = TransactionTemplate.create!(
      user: user,
      account: account,
      transaction_category: category,
      template_kind: template_kind,
      transaction_kind: :expense,
      name: name,
      source_amount_cents: 1_200,
      destination_amount_cents: 0,
      schedule_frequency: template_kind == :scheduled ? :monthly : :disabled,
      schedule_rule: template_kind == :scheduled ? "1" : "",
      scheduled_at_minutes: 540,
      timezone_utc_offset_minutes: 0,
      display_order: 1
    )
    tags.each { |tag| template.transaction_template_taggings.create!(user: user, transaction_tag: tag) }
    template
  end
end
