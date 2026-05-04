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
    create_category(user: other_user, name: "Other Groceries")

    sign_in user
    get transaction_categories_path

    assert_response :success
    assert_select "h1", text: /categories/i
    assert_select "li", text: /#{own_category.name}/i
    assert_select "li", text: /Other Groceries/i, count: 0
  end

  test "creates a category for current user" do
    user = create(:user)
    sign_in user

    post transaction_categories_path, params: {
      transaction_category: {
        name: "Salary",
        category_type: "income",
        icon_key: "1",
        color_hex: "22C55E",
        comment: "Monthly pay"
      }
    }

    category = user.transaction_categories.sole
    assert_redirected_to transaction_categories_path
    assert_equal "Salary", category.name
    assert_predicate category, :income?
  end

  test "updates a category for current user" do
    user = create(:user)
    category = create_category(user: user, name: "Groceries")
    sign_in user

    get edit_transaction_category_path(category)
    assert_response :success
    assert_select "h1", text: /edit category/i
    assert_select "input#transaction_category_hidden"

    patch transaction_category_path(category), params: {
      transaction_category: {
        name: "Restaurants",
        category_type: "expense",
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
    assert_equal 3, category.icon_key
    assert_equal "22C55E", category.color_hex
    assert_predicate category, :hidden?
    assert_equal "Dining out", category.comment
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

  def create_category(user:, name:)
    TransactionCategory.create!(
      user: user,
      name: name,
      category_type: :expense,
      icon_key: 1,
      color_hex: "F97316",
      display_order: 1
    )
  end
end
