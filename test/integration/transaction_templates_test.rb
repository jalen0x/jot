require "test_helper"

class TransactionTemplatesTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get transaction_templates_path

    assert_redirected_to new_user_session_path
  end

  test "lists only current user transaction templates" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Bills", category_type: :expense)
    template = create_template(user: user, account: account, category: category, name: "Rent", template_kind: :scheduled)
    discarded = create_template(user: user, account: account, category: category, name: "Archived", template_kind: :normal)
    discarded.discard!
    create_template(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Bills", category_type: :expense),
      name: "Other Rent",
      template_kind: :scheduled
    )

    sign_in user
    get transaction_templates_path

    assert_response :success
    assert_select "h1", text: /transaction templates/i
    assert_select "li", text: /#{template.name}/i
    assert_select "li", text: /Archived/i, count: 0
    assert_select "li", text: /Other Rent/i, count: 0
  end

  test "creates a scheduled transaction template for current user" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Bills", category_type: :expense)
    tag = create_tag(user: user, name: "Rent")
    sign_in user

    post transaction_templates_path, params: {
      transaction_template: {
        template_kind: "scheduled",
        transaction_kind: "expense",
        name: "Rent",
        account_id: account.id.to_s,
        destination_account_id: "",
        transaction_category_id: category.id.to_s,
        source_amount_cents: "120000",
        destination_amount_cents: "0",
        hide_amount: "0",
        comment: "Monthly rent",
        schedule_frequency: "monthly",
        schedule_rule: "-1",
        schedule_start_on: "2026-05-01",
        schedule_end_on: "2026-12-31",
        scheduled_at_minutes: "540",
        timezone_utc_offset_minutes: "480",
        transaction_tag_ids: [ tag.id.to_s ]
      }
    }

    template = user.transaction_templates.where(name: "Rent").sole
    assert_redirected_to transaction_templates_path
    assert_equal account, template.account
    assert_equal category, template.transaction_category
    assert_equal [ tag ], template.transaction_tags.to_a
    assert_equal 120_000, template.source_amount_cents
    assert_equal "Monthly rent", template.comment
    assert_predicate template, :scheduled?
    assert_predicate template, :monthly?
  end

  test "deletes a transaction template for current user" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Bills", category_type: :expense)
    template = create_template(user: user, account: account, category: category, name: "Rent", template_kind: :scheduled)
    sign_in user

    delete transaction_template_path(template)

    assert_redirected_to transaction_templates_path
    assert_predicate template.reload, :discarded?
  end

  test "does not delete another user's transaction template" do
    user = create(:user)
    other_user = create(:user)
    template = create_template(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Bills", category_type: :expense),
      name: "Other Rent",
      template_kind: :scheduled
    )
    sign_in user

    delete transaction_template_path(template)

    assert_response :not_found
    assert_predicate template.reload, :kept?
  end

  private

  def create_account(user:, name:)
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

  def create_template(user:, account:, category:, name:, template_kind:)
    TransactionTemplate.create!(
      user: user,
      account: account,
      transaction_category: category,
      template_kind: template_kind,
      transaction_kind: category.category_type,
      name: name,
      source_amount_cents: 1_000,
      destination_amount_cents: 0,
      schedule_frequency: template_kind.to_s == "scheduled" ? :monthly : :disabled,
      schedule_rule: template_kind.to_s == "scheduled" ? "-1" : "",
      scheduled_at_minutes: 540,
      timezone_utc_offset_minutes: 480,
      display_order: 1
    )
  end
end
