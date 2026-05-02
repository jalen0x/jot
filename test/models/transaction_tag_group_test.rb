require "test_helper"

class TransactionTagGroupTest < ActiveSupport::TestCase
  test "belongs to a user and normalizes name" do
    group = TransactionTagGroup.create!(
      user: create(:user),
      name: "  Context  ",
      display_order: 1
    )

    assert_equal "Context", group.name
  end
end
