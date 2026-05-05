require "test_helper"

class TransactionCategoriesTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get transaction_categories_path

    assert_redirected_to new_user_session_path
  end

  test "lists only current user categories" do
    user = create(:user)
    other_user = create(:user)
    own_category = create_category(user: user, name: "Groceries")
    child_category = create_category(user: user, name: "Produce", parent_category: own_category)
    create_category(user: other_user, name: "Other Groceries")
    create_category(user: other_user, name: "Other Produce")

    sign_in user
    get transaction_categories_path

    assert_response :success
    assert_select "h1", text: /categories/i
    assert_select "li", text: /#{own_category.name}/i
    assert_select "li", text: /#{child_category.name}/i
    assert_select "li", text: /Other Groceries/i, count: 0
    assert_select "li", text: /Other Produce/i, count: 0
    assert_select "form[action='#{transaction_category_path(own_category)}'][data-turbo-confirm]"
  end

  test "creates a category for current user" do
    user = create(:user)
    sign_in user

    get new_transaction_category_path
    assert_response :success
    assert_select "input#transaction_category_hidden"

    post transaction_categories_path, params: {
      transaction_category: {
        name: "Salary",
        category_type: "income",
        icon_key: "1",
        color_hex: "22C55E",
        hidden: "1",
        comment: "Monthly pay"
      }
    }

    category = user.transaction_categories.reload.sole
    assert_redirected_to transaction_categories_path
    assert_equal "Salary", category.name
    assert_predicate category, :income?
    assert_predicate category, :hidden?
  end

  test "creates a child category for current user's parent category" do
    user = create(:user)
    parent = create_category(user: user, name: "Food")
    create_category(user: user, name: "Groceries", parent_category: parent, display_order: 1)
    sign_in user

    post transaction_categories_path, params: {
      transaction_category: {
        name: "Produce",
        category_type: "expense",
        parent_category_id: parent.to_param,
        icon_key: "2",
        color_hex: "22C55E",
        comment: "Fresh food"
      }
    }

    assert_redirected_to transaction_categories_path
    category = user.transaction_categories.where(name: "Produce").sole
    assert_equal parent, category.parent_category
    assert_equal 2, category.display_order
  end

  test "updates a category for current user" do
    user = create(:user)
    parent = create_category(user: user, name: "Food")
    child_parent = create_category(user: user, name: "Produce", parent_category: parent)
    category = create_category(user: user, name: "Groceries")
    sign_in user

    get edit_transaction_category_path(category)
    assert_response :success
    assert_select "h1", text: /edit category/i
    assert_select "select#transaction_category_parent_category_id option[value='#{parent.to_param}']", text: /Food/i
    assert_select "select#transaction_category_parent_category_id option[value='#{child_parent.to_param}']", count: 0
    assert_select "input#transaction_category_hidden"

    patch transaction_category_path(category), params: {
      transaction_category: {
        name: "Restaurants",
        category_type: "expense",
        parent_category_id: parent.to_param,
        icon_key: "3",
        color_hex: "#22c55e",
        hidden: "1",
        comment: "Dining out"
      }
    }

    assert_redirected_to transaction_categories_path
    category.reload
    assert_equal "Restaurants", category.name
    assert_equal "expense", category.category_type
    assert_equal parent, category.parent_category
    assert_equal 3, category.icon_key
    assert_equal "22C55E", category.color_hex
    assert_predicate category, :hidden?
    assert_equal "Dining out", category.comment
  end

  test "does not create a category under a child category" do
    user = create(:user)
    parent = create_category(user: user, name: "Food")
    child = create_category(user: user, name: "Groceries", parent_category: parent)
    sign_in user

    post transaction_categories_path, params: {
      transaction_category: {
        name: "Produce",
        category_type: "expense",
        parent_category_id: child.to_param,
        icon_key: "2",
        color_hex: "22C55E",
        comment: "Too deep"
      }
    }

    assert_response :unprocessable_content
    assert_empty user.transaction_categories.where(name: "Produce")
    assert_match(/Parent category/i, response.body)
  end

  test "does not create a category under another user's parent category" do
    user = create(:user)
    other_parent = create_category(user: create(:user), name: "Other Food")
    sign_in user

    post transaction_categories_path, params: {
      transaction_category: {
        name: "Produce",
        category_type: "expense",
        parent_category_id: other_parent.to_param,
        icon_key: "2",
        color_hex: "22C55E",
        comment: "Fresh food"
      }
    }

    assert_response :unprocessable_content
    assert_empty user.transaction_categories.where(name: "Produce")
    assert_match(/Parent category/i, response.body)
  end

  test "does not update another user's category" do
    user = create(:user)
    other_user = create(:user)
    category = create_category(user: other_user, name: "Other Groceries")
    sign_in user

    patch transaction_category_path(category), params: {
      transaction_category: {
        name: "Changed",
        category_type: "expense",
        icon_key: "3",
        color_hex: "22C55E",
        hidden: "1",
        comment: "Changed"
      }
    }

    assert_response :not_found
    assert_equal "Other Groceries", category.reload.name
    refute_predicate category, :hidden?
  end

  test "deletes a category for current user" do
    user = create(:user)
    category = create_category(user: user, name: "Groceries")
    sign_in user

    delete transaction_category_path(category)

    assert_response :see_other
    assert_redirected_to transaction_categories_path
    assert_predicate category.reload, :discarded?
  end

  test "deletes child categories with their parent category" do
    user = create(:user)
    other_user = create(:user)
    parent = create_category(user: user, name: "Food")
    child = create_category(user: user, name: "Produce", parent_category: parent)
    other_parent = create_category(user: other_user, name: "Other Food")
    other_child = create_category(user: other_user, name: "Other Produce", parent_category: other_parent)
    sign_in user

    delete transaction_category_path(parent)

    assert_response :see_other
    assert_predicate parent.reload, :discarded?
    assert_predicate child.reload, :discarded?
    assert_predicate other_parent.reload, :kept?
    assert_predicate other_child.reload, :kept?
  end

  test "does not delete another user's category" do
    user = create(:user)
    other_user = create(:user)
    category = create_category(user: other_user, name: "Other Groceries")
    sign_in user

    delete transaction_category_path(category)

    assert_response :not_found
    assert_predicate category.reload, :kept?
  end

  private

  def create_category(user:, name:, parent_category: nil, display_order: 1)
    TransactionCategory.create!(
      user: user,
      name: name,
      category_type: :expense,
      parent_category: parent_category,
      icon_key: 1,
      color_hex: "F97316",
      display_order: display_order
    )
  end
end
