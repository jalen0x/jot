require "test_helper"

class DataManagementTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get data_management_path

    assert_redirected_to new_user_session_path
  end

  test "shows current user's data counts and management actions" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Food", category_type: :expense)
    tag = create_tag(user: user, name: "Meals")
    transaction = create_transaction(user: user, account: account, category: category)
    transaction.pictures.attach(io: StringIO.new("receipt"), filename: "receipt.txt", content_type: "text/plain", identify: false)
    InsightExplorer.create!(user: user, name: "Monthly", config: {}, display_order: 1)
    create_template(user: user, account: account, category: category, name: "Lunch", template_kind: :normal, tags: [ tag ])
    create_template(user: user, account: account, category: category, name: "Rent", template_kind: :scheduled, tags: [ tag ])
    other_account = create_account(user: other_user, name: "Other Checking")
    other_category = create_category(user: other_user, name: "Other Food", category_type: :expense)
    create_tag(user: other_user, name: "Other Meals")
    create_transaction(user: other_user, account: other_account, category: other_category)

    sign_in user
    get data_management_path

    assert_response :success
    assert_select "h1", text: /data management/i
    assert_select "article", text: /Accounts\s+1/i
    assert_select "article", text: /Categories\s+1/i
    assert_select "article", text: /Tags\s+1/i
    assert_select "article", text: /Transactions\s+1/i
    assert_select "article", text: /Pictures\s+1/i
    assert_select "article", text: /Insights\s+1/i
    assert_select "article", text: /Templates\s+1/i
    assert_select "article", text: /Scheduled\s+1/i
    assert_select "a[href='#{new_import_batch_path}']", text: /import/i
    assert_select "article", text: /Paste CSV, TSV, or JSON/i
    assert_select "form[action='#{data_exports_path}']", count: 3
    assert_select "button", text: /Export JSON/i
    assert_select "a[href='#{new_ledger_clearance_path}']", text: /clear/i
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

  def create_transaction(user:, account:, category:)
    Transaction.create!(
      user: user,
      account: account,
      transaction_category: category,
      transaction_kind: :expense,
      transacted_at: Time.zone.parse("2026-05-03 09:00:00"),
      timezone_utc_offset_minutes: 0,
      source_amount_cents: 1_200,
      destination_amount_cents: 0,
      comment: "Lunch"
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
