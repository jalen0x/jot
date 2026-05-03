require "test_helper"

class ApiV1TransactionCategoriesTest < ActionDispatch::IntegrationTest
  test "lists only the token owner's kept transaction categories" do
    user = create(:user)
    other_user = create(:user)
    income = create_category(user: user, name: "Salary", category_type: :income, display_order: 1)
    parent = create_category(user: user, name: "Food", category_type: :expense, display_order: 1)
    child = create_category(user: user, name: "Dining", category_type: :expense, parent_category: parent, display_order: 2)
    discarded_category = create_category(user: user, name: "Archived", category_type: :expense, display_order: 3)
    discarded_category.discard!
    create_category(user: other_user, name: "Other", category_type: :income, display_order: 1)
    raw_token = issue_token(user)

    get api_v1_transaction_categories_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "transaction_categories" ], body.keys
    categories = body.fetch("transaction_categories")
    assert_equal [ income.to_param, parent.to_param, child.to_param ], categories.map { |item| item.fetch("id") }

    child_json = categories.third
    assert_equal "Dining", child_json.fetch("name")
    assert_equal "expense", child_json.fetch("category_type")
    assert_equal parent.to_param, child_json.fetch("parent_category_id")
    assert_equal 2, child_json.fetch("display_order")
    assert_equal 1, child_json.fetch("icon_key")
    assert_equal "F97316", child_json.fetch("color_hex")
    assert_equal false, child_json.fetch("hidden")
    assert_equal "", child_json.fetch("comment")
    refute_includes child_json.keys, "user_id"
  end

  test "creates a transaction category for the token owner" do
    user = create(:user)
    parent = create_category(user: user, name: "Food", category_type: :expense, display_order: 1)
    create_category(user: user, name: "Lunch", category_type: :expense, parent_category: parent, display_order: 1)
    raw_token = issue_token(user)

    post api_v1_transaction_categories_path,
      params: {
        transaction_category: {
          name: "Dining",
          category_type: "expense",
          parent_category_id: parent.to_param,
          icon_key: "2",
          color_hex: "#f97316",
          comment: "Meals"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :created
    category = user.transaction_categories.where(name: "Dining").sole
    assert_equal parent, category.parent_category
    assert_equal 2, category.display_order
    assert_equal "F97316", category.color_hex

    body = JSON.parse(response.body)
    category_json = body.fetch("transaction_category")
    assert_equal category.to_param, category_json.fetch("id")
    assert_equal parent.to_param, category_json.fetch("parent_category_id")
    refute_includes category_json.keys, "user_id"
  end

  test "rejects another user's parent category" do
    user = create(:user)
    other_parent = create_category(user: create(:user), name: "Other Food", category_type: :expense, display_order: 1)
    raw_token = issue_token(user)

    post api_v1_transaction_categories_path,
      params: {
        transaction_category: {
          name: "Dining",
          category_type: "expense",
          parent_category_id: other_parent.to_param,
          icon_key: "2",
          color_hex: "F97316",
          comment: "Meals"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_empty user.transaction_categories.where(name: "Dining")
    assert_match(/Parent category is unavailable/i, response.body)
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

  def create_category(user:, name:, category_type:, display_order:, parent_category: nil)
    TransactionCategory.create!(
      user: user,
      parent_category: parent_category,
      name: name,
      category_type: category_type,
      icon_key: 1,
      color_hex: "F97316",
      display_order: display_order
    )
  end
end
