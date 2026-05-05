require "test_helper"

class TransactionTagsTest < ActionDispatch::IntegrationTest
  test "creates a tag for current user" do
    user = create(:user)
    group = TransactionTagGroup.create!(user: user, name: "Context", display_order: 1)
    sign_in user

    get new_transaction_tag_path
    assert_response :success
    assert_select "input#transaction_tag_hidden"

    post transaction_tags_path, params: {
      transaction_tag: {
        name: "Business",
        transaction_tag_group_id: group.id.to_s,
        hidden: "1"
      }
    }

    tag = user.transaction_tags.reload.sole
    assert_redirected_to transaction_tag_groups_path
    assert_equal "Business", tag.name
    assert_equal group, tag.transaction_tag_group
    assert_predicate tag, :hidden?
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

  test "updates a tag for current user" do
    user = create(:user)
    old_group = TransactionTagGroup.create!(user: user, name: "Context", display_order: 1)
    new_group = TransactionTagGroup.create!(user: user, name: "Trip", display_order: 2)
    tag = TransactionTag.create!(user: user, transaction_tag_group: old_group, name: "Business", display_order: 4)
    sign_in user

    get edit_transaction_tag_path(tag)
    assert_response :success
    assert_select "h1", text: /edit tag/i
    assert_select "input#transaction_tag_hidden"

    patch transaction_tag_path(tag), params: {
      transaction_tag: {
        name: "Flights",
        transaction_tag_group_id: new_group.id.to_s,
        hidden: "1"
      }
    }

    assert_redirected_to transaction_tag_groups_path
    tag.reload
    assert_equal "Flights", tag.name
    assert_equal new_group, tag.transaction_tag_group
    assert_predicate tag, :hidden?
    assert_equal 4, tag.display_order
  end

  test "does not update another user's tag" do
    user = create(:user)
    other_user = create(:user)
    tag = TransactionTag.create!(user: other_user, name: "Other Business", display_order: 1)
    sign_in user

    patch transaction_tag_path(tag), params: {
      transaction_tag: {
        name: "Changed",
        transaction_tag_group_id: "",
        hidden: "1"
      }
    }

    assert_response :not_found
    assert_equal "Other Business", tag.reload.name
    refute_predicate tag, :hidden?
  end

  test "deletes a tag for current user" do
    user = create(:user)
    tag = TransactionTag.create!(user: user, name: "Business", display_order: 1)
    sign_in user

    delete transaction_tag_path(tag)

    assert_response :see_other
    assert_redirected_to transaction_tag_groups_path
    assert_predicate tag.reload, :discarded?
  end

  test "does not delete another user's tag" do
    user = create(:user)
    other_user = create(:user)
    tag = TransactionTag.create!(user: other_user, name: "Other Business", display_order: 1)
    sign_in user

    delete transaction_tag_path(tag)

    assert_response :not_found
    assert_predicate tag.reload, :kept?
  end
end
