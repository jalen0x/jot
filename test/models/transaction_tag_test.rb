require "test_helper"

class TransactionTagTest < ActiveSupport::TestCase
  test "belongs to a user and optional group" do
    user = create(:user)
    group = TransactionTagGroup.create!(user: user, name: "Context", display_order: 1)

    tag = TransactionTag.create!(
      user: user,
      transaction_tag_group: group,
      name: "  Business  ",
      display_order: 1
    )

    assert_equal user, tag.user
    assert_equal group, tag.transaction_tag_group
    assert_equal "Business", tag.name
  end
end
