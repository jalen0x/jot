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

  test "shows one transaction category for the token owner" do
    user = create(:user)
    parent = create_category(user: user, name: "Food", category_type: :expense, display_order: 1)
    category = create_category(user: user, name: "Dining", category_type: :expense, parent_category: parent, display_order: 2)
    raw_token = issue_token(user)

    get api_v1_transaction_category_path(category), headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "transaction_category" ], body.keys
    category_json = body.fetch("transaction_category")
    assert_equal category.to_param, category_json.fetch("id")
    assert_equal "Dining", category_json.fetch("name")
    assert_equal "expense", category_json.fetch("category_type")
    assert_equal parent.to_param, category_json.fetch("parent_category_id")
    assert_equal 2, category_json.fetch("display_order")
    assert_equal false, category_json.fetch("hidden")
    refute_includes category_json.keys, "user_id"
  end

  test "does not show another user's transaction category" do
    user = create(:user)
    other_user = create(:user)
    category = create_category(user: other_user, name: "Other", category_type: :expense, display_order: 1)
    raw_token = issue_token(user)

    get api_v1_transaction_category_path(category), headers: json_headers(raw_token)

    assert_response :not_found
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

  test "updates a transaction category for the token owner" do
    user = create(:user)
    old_parent = create_category(user: user, name: "Food", category_type: :expense, display_order: 1)
    new_parent = create_category(user: user, name: "Travel", category_type: :expense, display_order: 2)
    category = create_category(user: user, name: "Dining", category_type: :expense, parent_category: old_parent, display_order: 3)
    raw_token = issue_token(user)

    patch api_v1_transaction_category_path(category),
      params: {
        transaction_category: {
          name: "Flights",
          category_type: "expense",
          parent_category_id: new_parent.to_param,
          icon_key: "3",
          color_hex: "#22c55e",
          comment: "Air travel",
          hidden: "true"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :success
    category.reload
    assert_equal "Flights", category.name
    assert_equal "expense", category.category_type
    assert_equal new_parent, category.parent_category
    assert_equal 3, category.icon_key
    assert_equal "22C55E", category.color_hex
    assert_equal "Air travel", category.comment
    assert_equal true, category.hidden

    category_json = JSON.parse(response.body).fetch("transaction_category")
    assert_equal category.to_param, category_json.fetch("id")
    assert_equal "Flights", category_json.fetch("name")
    assert_equal new_parent.to_param, category_json.fetch("parent_category_id")
    assert_equal true, category_json.fetch("hidden")
    refute_includes category_json.keys, "user_id"
  end

  test "unparents a transaction category" do
    user = create(:user)
    parent = create_category(user: user, name: "Food", category_type: :expense, display_order: 1)
    category = create_category(user: user, name: "Dining", category_type: :expense, parent_category: parent, display_order: 2)
    raw_token = issue_token(user)

    patch api_v1_transaction_category_path(category),
      params: {
        transaction_category: {
          name: "Dining",
          category_type: "expense",
          parent_category_id: "",
          icon_key: "1",
          color_hex: "F97316",
          comment: "",
          hidden: "false"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :success
    assert_nil category.reload.parent_category
    assert_nil JSON.parse(response.body).fetch("transaction_category").fetch("parent_category_id")
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

  test "rejects another user's parent category on update" do
    user = create(:user)
    category = create_category(user: user, name: "Dining", category_type: :expense, display_order: 1)
    other_parent = create_category(user: create(:user), name: "Other Food", category_type: :expense, display_order: 1)
    raw_token = issue_token(user)

    patch api_v1_transaction_category_path(category),
      params: {
        transaction_category: {
          name: "Dining",
          category_type: "expense",
          parent_category_id: other_parent.to_param,
          icon_key: "1",
          color_hex: "F97316",
          comment: "Meals",
          hidden: "false"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_nil category.reload.parent_category
    assert_match(/Parent category is unavailable/i, response.body)
  end

  test "does not update another user's transaction category" do
    user = create(:user)
    other_user = create(:user)
    category = create_category(user: other_user, name: "Other", category_type: :expense, display_order: 1)
    raw_token = issue_token(user)

    patch api_v1_transaction_category_path(category),
      params: {
        transaction_category: {
          name: "Changed",
          category_type: "expense",
          parent_category_id: "",
          icon_key: "2",
          color_hex: "22C55E",
          comment: "Changed",
          hidden: "true"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_equal "Other", category.reload.name
    assert_equal false, category.hidden
  end

  test "deletes a transaction category for the token owner" do
    user = create(:user)
    category = create_category(user: user, name: "Dining", category_type: :expense, display_order: 1)
    raw_token = issue_token(user)

    delete api_v1_transaction_category_path(category), headers: json_headers(raw_token)

    assert_response :no_content
    assert_empty response.body
    assert_predicate category.reload, :discarded?
  end

  test "does not delete another user's transaction category" do
    user = create(:user)
    other_user = create(:user)
    category = create_category(user: other_user, name: "Other", category_type: :expense, display_order: 1)
    raw_token = issue_token(user)

    delete api_v1_transaction_category_path(category), headers: json_headers(raw_token)

    assert_response :not_found
    refute_predicate category.reload, :discarded?
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
