require "test_helper"

class TransactionCategoryTest < ActiveSupport::TestCase
  test "belongs to a user and normalizes display fields" do
    category = TransactionCategory.create!(
      user: create(:user),
      name: "  Groceries  ",
      category_type: :expense,
      icon_key: 12,
      color_hex: "#f97316",
      display_order: 1,
      comment: "  Weekly food  "
    )

    assert_equal "Groceries", category.name
    assert_equal "F97316", category.color_hex
    assert_equal "Weekly food", category.comment
  end

  test "database rejects a category without an owner" do
    category = TransactionCategory.create!(
      user: create(:user),
      name: "Salary",
      category_type: :income,
      icon_key: 1,
      color_hex: "22C55E",
      display_order: 1
    )

    error = assert_raises(ActiveRecord::NotNullViolation) do
      category.update_column(:user_id, nil)
    end

    assert_match(/user_id/i, error.message)
  end
end
