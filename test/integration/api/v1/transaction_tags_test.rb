require "test_helper"

class ApiV1TransactionTagsTest < ActionDispatch::IntegrationTest
  test "lists only the token owner's kept transaction tags" do
    user = create(:user)
    other_user = create(:user)
    group = create_tag_group(user: user, name: "Food", display_order: 1)
    meals = create_tag(user: user, name: "Meals", display_order: 1, transaction_tag_group: group)
    travel = create_tag(user: user, name: "Travel", display_order: 2)
    discarded_tag = create_tag(user: user, name: "Archived", display_order: 3)
    discarded_tag.discard!
    create_tag(user: other_user, name: "Other", display_order: 1)
    raw_token = issue_token(user)

    get api_v1_transaction_tags_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "transaction_tags" ], body.keys
    tags = body.fetch("transaction_tags")
    assert_equal [ meals.to_param, travel.to_param ], tags.map { |item| item.fetch("id") }

    tag_json = tags.first
    assert_equal "Meals", tag_json.fetch("name")
    assert_equal group.to_param, tag_json.fetch("transaction_tag_group_id")
    assert_equal 1, tag_json.fetch("display_order")
    assert_equal false, tag_json.fetch("hidden")
    refute_includes tag_json.keys, "user_id"
  end

  test "creates a transaction tag for the token owner" do
    user = create(:user)
    group = create_tag_group(user: user, name: "Food", display_order: 1)
    create_tag(user: user, name: "Existing", display_order: 1)
    raw_token = issue_token(user)

    post api_v1_transaction_tags_path,
      params: {
        transaction_tag: {
          name: "Meals",
          transaction_tag_group_id: group.to_param
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :created
    tag = user.transaction_tags.where(name: "Meals").sole
    assert_equal group, tag.transaction_tag_group
    assert_equal 2, tag.display_order

    body = JSON.parse(response.body)
    tag_json = body.fetch("transaction_tag")
    assert_equal tag.to_param, tag_json.fetch("id")
    assert_equal "Meals", tag_json.fetch("name")
    assert_equal group.to_param, tag_json.fetch("transaction_tag_group_id")
    assert_equal 2, tag_json.fetch("display_order")
    refute_includes tag_json.keys, "user_id"
  end

  test "updates a transaction tag for the token owner" do
    user = create(:user)
    old_group = create_tag_group(user: user, name: "Food", display_order: 1)
    new_group = create_tag_group(user: user, name: "Travel", display_order: 2)
    tag = create_tag(user: user, name: "Meals", display_order: 1, transaction_tag_group: old_group)
    raw_token = issue_token(user)

    patch api_v1_transaction_tag_path(tag),
      params: {
        transaction_tag: {
          name: "Flights",
          transaction_tag_group_id: new_group.to_param,
          hidden: "true"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :success
    tag.reload
    assert_equal "Flights", tag.name
    assert_equal new_group, tag.transaction_tag_group
    assert_equal true, tag.hidden

    tag_json = JSON.parse(response.body).fetch("transaction_tag")
    assert_equal tag.to_param, tag_json.fetch("id")
    assert_equal "Flights", tag_json.fetch("name")
    assert_equal new_group.to_param, tag_json.fetch("transaction_tag_group_id")
    assert_equal true, tag_json.fetch("hidden")
    refute_includes tag_json.keys, "user_id"
  end

  test "ungroups a transaction tag" do
    user = create(:user)
    group = create_tag_group(user: user, name: "Food", display_order: 1)
    tag = create_tag(user: user, name: "Meals", display_order: 1, transaction_tag_group: group)
    raw_token = issue_token(user)

    patch api_v1_transaction_tag_path(tag),
      params: {
        transaction_tag: {
          name: "Meals",
          transaction_tag_group_id: "",
          hidden: "false"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :success
    assert_nil tag.reload.transaction_tag_group
    assert_nil JSON.parse(response.body).fetch("transaction_tag").fetch("transaction_tag_group_id")
  end

  test "rejects another user's transaction tag group" do
    user = create(:user)
    other_group = create_tag_group(user: create(:user), name: "Other Food", display_order: 1)
    raw_token = issue_token(user)

    post api_v1_transaction_tags_path,
      params: {
        transaction_tag: {
          name: "Meals",
          transaction_tag_group_id: other_group.to_param
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_empty user.transaction_tags.where(name: "Meals")
    assert_match(/Transaction tag group is unavailable/i, response.body)
  end

  test "rejects another user's transaction tag group on update" do
    user = create(:user)
    tag = create_tag(user: user, name: "Meals", display_order: 1)
    other_group = create_tag_group(user: create(:user), name: "Other Food", display_order: 1)
    raw_token = issue_token(user)

    patch api_v1_transaction_tag_path(tag),
      params: {
        transaction_tag: {
          name: "Meals",
          transaction_tag_group_id: other_group.to_param,
          hidden: "false"
        }
      },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_nil tag.reload.transaction_tag_group
    assert_match(/Transaction tag group is unavailable/i, response.body)
  end

  test "does not update another user's transaction tag" do
    user = create(:user)
    other_user = create(:user)
    tag = create_tag(user: other_user, name: "Other", display_order: 1)
    raw_token = issue_token(user)

    patch api_v1_transaction_tag_path(tag),
      params: { transaction_tag: { name: "Changed", transaction_tag_group_id: "", hidden: "true" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_equal "Other", tag.reload.name
    assert_equal false, tag.hidden
  end

  test "deletes a transaction tag for the token owner" do
    user = create(:user)
    tag = create_tag(user: user, name: "Meals", display_order: 1)
    raw_token = issue_token(user)

    delete api_v1_transaction_tag_path(tag), headers: json_headers(raw_token)

    assert_response :no_content
    assert_empty response.body
    assert_predicate tag.reload, :discarded?
  end

  test "does not delete another user's transaction tag" do
    user = create(:user)
    other_user = create(:user)
    tag = create_tag(user: other_user, name: "Other", display_order: 1)
    raw_token = issue_token(user)

    delete api_v1_transaction_tag_path(tag), headers: json_headers(raw_token)

    assert_response :not_found
    refute_predicate tag.reload, :discarded?
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

  def create_tag_group(user:, name:, display_order:)
    TransactionTagGroup.create!(user: user, name: name, display_order: display_order)
  end

  def create_tag(user:, name:, display_order:, transaction_tag_group: nil)
    TransactionTag.create!(
      user: user,
      name: name,
      display_order: display_order,
      transaction_tag_group: transaction_tag_group
    )
  end
end
