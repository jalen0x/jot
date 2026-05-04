require "test_helper"

class ApiV1TransactionTemplatesTest < ActionDispatch::IntegrationTest
  test "lists only the token owner's kept transaction templates" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Food", category_type: :expense)
    tag = create_tag(user: user, name: "Rent")
    normal = create_template(user: user, account: account, category: category, name: "Lunch", template_kind: :normal, display_order: 1)
    scheduled = create_template(
      user: user,
      account: account,
      category: category,
      name: "Rent",
      template_kind: :scheduled,
      display_order: 2,
      schedule_frequency: :monthly,
      schedule_rule: "-1",
      schedule_start_on: Date.new(2026, 5, 1),
      scheduled_at_minutes: 540,
      timezone_utc_offset_minutes: 480,
      tags: [ tag ]
    )
    discarded = create_template(user: user, account: account, category: category, name: "Archived", template_kind: :normal, display_order: 3)
    discarded.discard!
    create_template(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Food", category_type: :expense),
      name: "Other",
      template_kind: :normal,
      display_order: 1
    )
    raw_token = issue_token(user)

    get api_v1_transaction_templates_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "transaction_templates" ], body.keys
    templates = body.fetch("transaction_templates")
    assert_equal [ normal.to_param, scheduled.to_param ], templates.map { |item| item.fetch("id") }

    scheduled_json = templates.second
    assert_equal "scheduled", scheduled_json.fetch("template_kind")
    assert_equal "expense", scheduled_json.fetch("transaction_kind")
    assert_equal account.to_param, scheduled_json.fetch("account_id")
    assert_equal category.to_param, scheduled_json.fetch("transaction_category_id")
    assert_equal "monthly", scheduled_json.fetch("schedule_frequency")
    assert_equal "-1", scheduled_json.fetch("schedule_rule")
    assert_equal "2026-05-01", scheduled_json.fetch("schedule_start_on")
    assert_equal 540, scheduled_json.fetch("scheduled_at_minutes")
    assert_equal 480, scheduled_json.fetch("timezone_utc_offset_minutes")
    assert_equal [ tag.to_param ], scheduled_json.fetch("transaction_tag_ids")
    refute_includes scheduled_json.keys, "user_id"
  end

  test "shows one transaction template for the token owner" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Bills", category_type: :expense)
    tag = create_tag(user: user, name: "Rent")
    template = create_template(
      user: user,
      account: account,
      category: category,
      name: "Rent",
      template_kind: :scheduled,
      display_order: 1,
      schedule_frequency: :monthly,
      schedule_rule: "-1",
      schedule_start_on: Date.new(2026, 5, 1),
      scheduled_at_minutes: 540,
      timezone_utc_offset_minutes: 480,
      tags: [ tag ]
    )
    raw_token = issue_token(user)

    get api_v1_transaction_template_path(template), headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "transaction_template" ], body.keys
    template_json = body.fetch("transaction_template")
    assert_equal template.to_param, template_json.fetch("id")
    assert_equal "Rent", template_json.fetch("name")
    assert_equal "scheduled", template_json.fetch("template_kind")
    assert_equal "expense", template_json.fetch("transaction_kind")
    assert_equal account.to_param, template_json.fetch("account_id")
    assert_equal category.to_param, template_json.fetch("transaction_category_id")
    assert_equal "monthly", template_json.fetch("schedule_frequency")
    assert_equal "-1", template_json.fetch("schedule_rule")
    assert_equal "2026-05-01", template_json.fetch("schedule_start_on")
    assert_equal [ tag.to_param ], template_json.fetch("transaction_tag_ids")
    refute_includes template_json.keys, "user_id"
  end

  test "does not show another user's transaction template" do
    user = create(:user)
    other_user = create(:user)
    template = create_template(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Bills", category_type: :expense),
      name: "Other Rent",
      template_kind: :scheduled,
      display_order: 1
    )
    raw_token = issue_token(user)

    get api_v1_transaction_template_path(template), headers: json_headers(raw_token)

    assert_response :not_found
  end

  test "creates a scheduled transaction template for the token owner" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Bills", category_type: :expense)
    tag = create_tag(user: user, name: "Rent")
    create_template(user: user, account: account, category: category, name: "Existing", template_kind: :scheduled, display_order: 1)
    raw_token = issue_token(user)

    post api_v1_transaction_templates_path,
      params: {
        transaction_template: {
          template_kind: "scheduled",
          transaction_kind: "expense",
          name: "  Rent  ",
          account_id: account.to_param,
          transaction_category_id: category.to_param,
          source_amount_cents: "120000",
          destination_amount_cents: "0",
          hide_amount: "false",
          comment: "  Monthly rent  ",
          schedule_frequency: "monthly",
          schedule_rule: "-1",
          schedule_start_on: "2026-05-01",
          schedule_end_on: "2026-12-31",
          scheduled_at_minutes: "540",
          timezone_utc_offset_minutes: "480",
          transaction_tag_ids: [ tag.to_param ]
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :created
    template = user.transaction_templates.where(name: "Rent").sole
    assert_equal account, template.account
    assert_equal category, template.transaction_category
    assert_equal [ tag ], template.transaction_tags.to_a
    assert_equal 2, template.display_order
    assert_equal 120_000, template.source_amount_cents
    assert_equal "Monthly rent", template.comment
    assert_predicate template, :scheduled?
    assert_predicate template, :monthly?

    body = JSON.parse(response.body)
    template_json = body.fetch("transaction_template")
    assert_equal template.to_param, template_json.fetch("id")
    assert_equal "Rent", template_json.fetch("name")
    assert_equal 2, template_json.fetch("display_order")
    assert_equal [ tag.to_param ], template_json.fetch("transaction_tag_ids")
    refute_includes template_json.keys, "user_id"
  end

  test "rejects another user's owned records" do
    user = create(:user)
    other_user = create(:user)
    other_account = create_account(user: other_user, name: "Other Checking")
    other_category = create_category(user: other_user, name: "Other Bills", category_type: :expense)
    other_tag = create_tag(user: other_user, name: "Other Rent")
    raw_token = issue_token(user)

    post api_v1_transaction_templates_path,
      params: {
        transaction_template: {
          template_kind: "scheduled",
          transaction_kind: "expense",
          name: "Rent",
          account_id: other_account.to_param,
          transaction_category_id: other_category.to_param,
          source_amount_cents: "120000",
          destination_amount_cents: "0",
          hide_amount: "false",
          comment: "Monthly rent",
          schedule_frequency: "monthly",
          schedule_rule: "-1",
          scheduled_at_minutes: "540",
          timezone_utc_offset_minutes: "480",
          transaction_tag_ids: [ other_tag.to_param ]
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_empty user.transaction_templates.where(name: "Rent")
    assert_match(/Account is unavailable/i, response.body)
    assert_match(/Transaction category is unavailable/i, response.body)
    assert_match(/Transaction tags include unavailable tags/i, response.body)
  end

  test "rejects categories that do not match the template transaction kind" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    expense_category = create_category(user: user, name: "Food", category_type: :expense)
    raw_token = issue_token(user)

    post api_v1_transaction_templates_path,
      params: {
        transaction_template: {
          template_kind: "normal",
          transaction_kind: "income",
          name: "Paycheck",
          account_id: account.to_param,
          transaction_category_id: expense_category.to_param,
          source_amount_cents: "200000",
          destination_amount_cents: "0",
          hide_amount: "false",
          comment: "Salary",
          schedule_frequency: "disabled",
          schedule_rule: "",
          scheduled_at_minutes: "0",
          timezone_utc_offset_minutes: "0",
          transaction_tag_ids: []
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_empty user.transaction_templates.where(name: "Paycheck")
    assert_match(/Transaction category does not match transaction type/i, response.body)
  end

  test "updates an owned transaction template and replaces tags" do
    user = create(:user)
    original_account = create_account(user: user, name: "Checking")
    updated_account = create_account(user: user, name: "Savings")
    original_category = create_category(user: user, name: "Food", category_type: :expense)
    updated_category = create_category(user: user, name: "Bills", category_type: :expense)
    original_tag = create_tag(user: user, name: "Meals")
    updated_tag = create_tag(user: user, name: "Rent")
    template = create_template(
      user: user,
      account: original_account,
      category: original_category,
      name: "Lunch",
      template_kind: :normal,
      display_order: 1,
      tags: [ original_tag ]
    )
    raw_token = issue_token(user)

    patch api_v1_transaction_template_path(template),
      params: {
        transaction_template: {
          template_kind: "scheduled",
          transaction_kind: "expense",
          name: "  Rent  ",
          account_id: updated_account.to_param,
          transaction_category_id: updated_category.to_param,
          source_amount_cents: "120000",
          destination_amount_cents: "0",
          hide_amount: "true",
          hidden: "true",
          display_order: "5",
          comment: "  Monthly rent  ",
          schedule_frequency: "monthly",
          schedule_rule: "-1",
          schedule_start_on: "2026-05-01",
          schedule_end_on: "2026-12-31",
          scheduled_at_minutes: "540",
          timezone_utc_offset_minutes: "480",
          transaction_tag_ids: [ updated_tag.to_param ]
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :success
    template.reload
    assert_equal "Rent", template.name
    assert_equal updated_account, template.account
    assert_equal updated_category, template.transaction_category
    assert_equal [ updated_tag ], template.transaction_tags.to_a
    assert_equal 5, template.display_order
    assert_equal true, template.hidden
    assert_predicate template, :scheduled?
    assert_predicate template, :monthly?
    assert_equal Date.new(2026, 5, 1), template.schedule_start_on
    assert_equal Date.new(2026, 12, 31), template.schedule_end_on
    assert_equal 540, template.scheduled_at_minutes
    assert_equal 480, template.timezone_utc_offset_minutes

    body = JSON.parse(response.body)
    template_json = body.fetch("transaction_template")
    assert_equal template.to_param, template_json.fetch("id")
    assert_equal true, template_json.fetch("hidden")
    assert_equal 5, template_json.fetch("display_order")
    assert_equal [ updated_tag.to_param ], template_json.fetch("transaction_tag_ids")
  end

  test "rejects updating a template with another user's owned records" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Bills", category_type: :expense)
    tag = create_tag(user: user, name: "Rent")
    template = create_template(user: user, account: account, category: category, name: "Rent", template_kind: :scheduled, display_order: 1, tags: [ tag ])
    other_user = create(:user)
    other_account = create_account(user: other_user, name: "Other Checking")
    other_category = create_category(user: other_user, name: "Other Bills", category_type: :expense)
    other_tag = create_tag(user: other_user, name: "Other Rent")
    raw_token = issue_token(user)

    patch api_v1_transaction_template_path(template),
      params: {
        transaction_template: {
          template_kind: "scheduled",
          transaction_kind: "expense",
          name: "Other Rent",
          account_id: other_account.to_param,
          transaction_category_id: other_category.to_param,
          source_amount_cents: "130000",
          destination_amount_cents: "0",
          hide_amount: "false",
          comment: "Should not save",
          schedule_frequency: "monthly",
          schedule_rule: "-1",
          scheduled_at_minutes: "540",
          timezone_utc_offset_minutes: "480",
          transaction_tag_ids: [ other_tag.to_param ]
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    template.reload
    assert_equal "Rent", template.name
    assert_equal account, template.account
    assert_equal category, template.transaction_category
    assert_equal [ tag ], template.transaction_tags.to_a
    assert_match(/Account is unavailable/i, response.body)
    assert_match(/Transaction category is unavailable/i, response.body)
    assert_match(/Transaction tags include unavailable tags/i, response.body)
  end

  test "soft deletes an owned transaction template" do
    user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Bills", category_type: :expense)
    template = create_template(user: user, account: account, category: category, name: "Rent", template_kind: :scheduled, display_order: 1)
    raw_token = issue_token(user)

    delete api_v1_transaction_template_path(template), headers: json_headers(raw_token)

    assert_response :no_content
    assert_predicate template.reload, :discarded?

    get api_v1_transaction_templates_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_empty body.fetch("transaction_templates")
  end

  test "does not delete another user's transaction template" do
    user = create(:user)
    other_user = create(:user)
    other_template = create_template(
      user: other_user,
      account: create_account(user: other_user, name: "Other Checking"),
      category: create_category(user: other_user, name: "Other Bills", category_type: :expense),
      name: "Other Rent",
      template_kind: :scheduled,
      display_order: 1
    )
    raw_token = issue_token(user)

    delete api_v1_transaction_template_path(other_template), headers: json_headers(raw_token)

    assert_response :not_found
    assert_predicate other_template.reload, :kept?
  end

  private

  def issue_token(user)
    ApiTokenIssuer.new.issue(user: user, attributes: { name: "API", expires_in_days: "" }).raw_token
  end

  def json_headers(raw_token)
    {
      "Accept" => "application/json",
      "Authorization" => "Bearer #{raw_token}"
    }
  end

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

  def create_template(user:, account:, category:, name:, template_kind:, display_order:, schedule_frequency: :disabled, schedule_rule: "", schedule_start_on: nil, scheduled_at_minutes: 0, timezone_utc_offset_minutes: 0, tags: [])
    template = TransactionTemplate.create!(
      user: user,
      account: account,
      transaction_category: category,
      template_kind: template_kind,
      transaction_kind: category.category_type,
      name: name,
      source_amount_cents: 1_000,
      destination_amount_cents: 0,
      schedule_frequency: schedule_frequency,
      schedule_rule: schedule_rule,
      schedule_start_on: schedule_start_on,
      scheduled_at_minutes: scheduled_at_minutes,
      timezone_utc_offset_minutes: timezone_utc_offset_minutes,
      display_order: display_order
    )

    tags.each do |tag|
      TransactionTemplateTagging.create!(user: user, transaction_template: template, transaction_tag: tag)
    end

    template
  end
end
