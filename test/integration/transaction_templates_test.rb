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
    assert_select "tr", text: /#{template.name}/i
    assert_select "tr", text: /10.00 USD/
    assert_select "tr", text: /1000 cents/, count: 0
    assert_select "tr", text: /Archived/i, count: 0
    assert_select "tr", text: /Other Rent/i, count: 0
    assert_select "form[action='#{transaction_template_path(template)}'][data-turbo-confirm]"
  end

  test "creates a scheduled transaction template for current user" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Bills", category_type: :expense)
    tag = create_tag(user: user, name: "Rent")
    sign_in user

    get new_transaction_template_path
    assert_response :success
    assert_select "input#transaction_template_hidden"

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
        hidden: "1",
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
    assert_predicate template, :hidden?
    assert_equal "Monthly rent", template.comment
    assert_predicate template, :scheduled?
    assert_predicate template, :monthly?
  end

  test "updates a transaction template for current user" do
    user = create(:user)
    old_account = create_account(user: user, name: "Checking")
    new_account = create_account(user: user, name: "Savings")
    old_category = create_category(user: user, name: "Food", category_type: :expense)
    new_category = create_category(user: user, name: "Bills", category_type: :expense)
    old_tag = create_tag(user: user, name: "Meals")
    new_tag = create_tag(user: user, name: "Rent")
    template = create_template(
      user: user,
      account: old_account,
      category: old_category,
      name: "Lunch",
      template_kind: :normal,
      tags: [ old_tag ]
    )
    sign_in user

    get edit_transaction_template_path(template)
    assert_response :success
    assert_select "h1", text: /edit transaction template/i
    assert_select "input#transaction_template_hidden"

    patch transaction_template_path(template), params: {
      transaction_template: {
        template_kind: "scheduled",
        transaction_kind: "expense",
        name: "Rent",
        account_id: new_account.id.to_s,
        destination_account_id: "",
        transaction_category_id: new_category.id.to_s,
        source_amount_cents: "120000",
        destination_amount_cents: "0",
        hide_amount: "1",
        hidden: "1",
        comment: "Monthly rent",
        schedule_frequency: "monthly",
        schedule_rule: "-1",
        schedule_start_on: "2026-05-01",
        schedule_end_on: "2026-12-31",
        scheduled_at_minutes: "540",
        timezone_utc_offset_minutes: "480",
        transaction_tag_ids: [ new_tag.id.to_s ]
      }
    }

    assert_redirected_to transaction_templates_path
    template.reload
    assert_equal "Rent", template.name
    assert_equal new_account, template.account
    assert_equal new_category, template.transaction_category
    assert_equal [ new_tag ], template.transaction_tags.to_a
    assert_equal 1, template.display_order
    assert_equal 120_000, template.source_amount_cents
    assert_predicate template, :hide_amount?
    assert_predicate template, :hidden?
    assert_predicate template, :scheduled?
    assert_predicate template, :monthly?
    assert_equal Date.new(2026, 5, 1), template.schedule_start_on
    assert_equal Date.new(2026, 12, 31), template.schedule_end_on
    assert_equal 540, template.scheduled_at_minutes
    assert_equal 480, template.timezone_utc_offset_minutes
  end

  test "does not update another user's transaction template" do
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

    patch transaction_template_path(template), params: {
      transaction_template: {
        template_kind: "normal",
        transaction_kind: "expense",
        name: "Changed",
        account_id: template.account.id.to_s,
        destination_account_id: "",
        transaction_category_id: template.transaction_category.id.to_s,
        source_amount_cents: "130000",
        destination_amount_cents: "0",
        hide_amount: "0",
        hidden: "1",
        comment: "Changed",
        schedule_frequency: "disabled",
        schedule_rule: "",
        scheduled_at_minutes: "0",
        timezone_utc_offset_minutes: "0"
      }
    }

    assert_response :not_found
    assert_equal "Other Rent", template.reload.name
    refute_predicate template, :hidden?
  end

  test "deletes a transaction template for current user" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Bills", category_type: :expense)
    template = create_template(user: user, account: account, category: category, name: "Rent", template_kind: :scheduled)
    sign_in user

    delete transaction_template_path(template)

    assert_response :see_other
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

  def create_template(user:, account:, category:, name:, template_kind:, tags: [])
    template = TransactionTemplate.create!(
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
    tags.each { |tag| TransactionTemplateTagging.create!(user: user, transaction_template: template, transaction_tag: tag) }
    template
  end
end
