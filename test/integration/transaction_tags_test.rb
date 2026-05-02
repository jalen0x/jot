require "test_helper"

class TransactionTagsTest < ActionDispatch::IntegrationTest
  test "creates a tag for current user" do
    user = create(:user)
    group = TransactionTagGroup.create!(user: user, name: "Context", display_order: 1)
    sign_in user

    post transaction_tags_path, params: {
      transaction_tag: {
        name: "Business",
        transaction_tag_group_id: group.id.to_s
      }
    }

    tag = user.transaction_tags.sole
    assert_redirected_to transaction_tag_groups_path
    assert_equal "Business", tag.name
    assert_equal group, tag.transaction_tag_group
  end

  test "rejects another user's tag group" do
    user = create(:user)
    other_group = TransactionTagGroup.create!(user: create(:user), name: "Other Context", display_order: 1)
    sign_in user

    assert_no_difference -> { user.transaction_tags.count } do
      post transaction_tags_path, params: {
        transaction_tag: {
          name: "Business",
          transaction_tag_group_id: other_group.id.to_s
        }
      }
    end

    assert_response :not_found
  end
end
