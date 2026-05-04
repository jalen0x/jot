require "test_helper"

class ApiV1DataStatisticsTest < ActionDispatch::IntegrationTest
  test "returns data management statistics for the token owner" do
    user = create(:user)
    other_user = create(:user)
    account = create_account(user: user, name: "Checking")
    category = create_category(user: user, name: "Food", category_type: :expense)
    tag = create_tag(user: user, name: "Meals")
    transaction = create_transaction(user: user, account: account, category: category, comment: "Lunch")
    transaction.pictures.attach(io: StringIO.new("receipt"), filename: "receipt.txt", content_type: "text/plain", identify: false)
    InsightExplorer.create!(user: user, name: "Monthly", config: {}, display_order: 1)
    create_template(user: user, account: account, category: category, name: "Lunch", template_kind: :normal, tags: [ tag ])
    create_template(user: user, account: account, category: category, name: "Rent", template_kind: :scheduled, tags: [ tag ])
    create_account(user: other_user, name: "Other")
    other_category = create_category(user: other_user, name: "Other Food", category_type: :expense)
    create_tag(user: other_user, name: "Other")
    create_transaction(user: other_user, account: create_account(user: other_user, name: "Other Cash"), category: other_category, comment: "Other")
    raw_token = issue_token(user)

    get api_v1_data_statistics_path, headers: json_headers(raw_token)

    assert_response :success
    assert_equal({
      "data_statistics" => {
        "account_count" => 1,
        "transaction_category_count" => 1,
        "transaction_tag_count" => 1,
        "transaction_count" => 1,
        "transaction_picture_count" => 1,
        "insight_explorer_count" => 1,
        "transaction_template_count" => 1,
        "scheduled_transaction_count" => 1
      }
    }, JSON.parse(response.body))
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
