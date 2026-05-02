require "test_helper"

class TransactionTagGroupsTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get transaction_tag_groups_path

    assert_redirected_to new_user_session_path
  end

  test "lists only current user tag groups and tags" do
    user = create(:user)
    other_user = create(:user)
    group = TransactionTagGroup.create!(user: user, name: "Context", display_order: 1)
    TransactionTag.create!(user: user, transaction_tag_group: group, name: "Business", display_order: 1)
    other_group = TransactionTagGroup.create!(user: other_user, name: "Other Context", display_order: 1)
    TransactionTag.create!(user: other_user, transaction_tag_group: other_group, name: "Other Business", display_order: 1)

    sign_in user
    get transaction_tag_groups_path

    assert_response :success
    assert_select "h1", text: /tags/i
    assert_select "li", text: /Context/i
    assert_select "li", text: /Business/i
    assert_select "li", text: /Other Context/i, count: 0
    assert_select "li", text: /Other Business/i, count: 0
  end

  test "creates a tag group for current user" do
    user = create(:user)
    sign_in user

    post transaction_tag_groups_path, params: { transaction_tag_group: { name: "Context" } }

    group = user.transaction_tag_groups.sole
    assert_redirected_to transaction_tag_groups_path
    assert_equal "Context", group.name
  end
end
