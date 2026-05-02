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
