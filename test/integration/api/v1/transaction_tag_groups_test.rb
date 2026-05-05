require "test_helper"

class ApiV1TransactionTagGroupsTest < ActionDispatch::IntegrationTest
  test "lists only the token owner's kept transaction tag groups" do
    user = create(:user)
    other_user = create(:user)
    bills = create_tag_group(user: user, name: "Bills", display_order: 1)
    travel = create_tag_group(user: user, name: "Travel", display_order: 2)
    discarded_group = create_tag_group(user: user, name: "Archived", display_order: 3)
    discarded_group.discard!
    create_tag_group(user: other_user, name: "Other", display_order: 1)
    raw_token = issue_token(user)

    get api_v1_transaction_tag_groups_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "transaction_tag_groups" ], body.keys
    tag_groups = body.fetch("transaction_tag_groups")
    assert_equal [ bills.to_param, travel.to_param ], tag_groups.map { |item| item.fetch("id") }

    group_json = tag_groups.first
    assert_equal "Bills", group_json.fetch("name")
    assert_equal 1, group_json.fetch("display_order")
    refute_includes group_json.keys, "user_id"
  end

  test "shows one transaction tag group for the token owner" do
    user = create(:user)
    tag_group = create_tag_group(user: user, name: "Bills", display_order: 1)
    raw_token = issue_token(user)

    get api_v1_transaction_tag_group_path(tag_group), headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "transaction_tag_group" ], body.keys
    group_json = body.fetch("transaction_tag_group")
    assert_equal tag_group.to_param, group_json.fetch("id")
    assert_equal "Bills", group_json.fetch("name")
    assert_equal 1, group_json.fetch("display_order")
    refute_includes group_json.keys, "user_id"
  end

  test "does not show another user's transaction tag group" do
    user = create(:user)
    other_user = create(:user)
    tag_group = create_tag_group(user: other_user, name: "Other", display_order: 1)
    raw_token = issue_token(user)

    get api_v1_transaction_tag_group_path(tag_group), headers: json_headers(raw_token)

    assert_response :not_found
  end

  test "creates a transaction tag group for the token owner" do
    user = create(:user)
    create_tag_group(user: user, name: "Existing", display_order: 1)
    raw_token = issue_token(user)

    post api_v1_transaction_tag_groups_path,
      params: { transaction_tag_group: { name: "Meals" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :created
    tag_group = user.transaction_tag_groups.where(name: "Meals").sole
    assert_equal 2, tag_group.display_order

    body = JSON.parse(response.body)
    group_json = body.fetch("transaction_tag_group")
    assert_equal tag_group.to_param, group_json.fetch("id")
    assert_equal "Meals", group_json.fetch("name")
    assert_equal 2, group_json.fetch("display_order")
    refute_includes group_json.keys, "user_id"
  end

  test "updates a transaction tag group for the token owner" do
    user = create(:user)
    tag_group = create_tag_group(user: user, name: "Bills", display_order: 1)
    raw_token = issue_token(user)

    patch api_v1_transaction_tag_group_path(tag_group),
      params: { transaction_tag_group: { name: "Subscriptions", display_order: "5" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :success
    tag_group.reload
    assert_equal "Subscriptions", tag_group.name
    assert_equal 5, tag_group.display_order

    group_json = JSON.parse(response.body).fetch("transaction_tag_group")
    assert_equal tag_group.to_param, group_json.fetch("id")
    assert_equal "Subscriptions", group_json.fetch("name")
    assert_equal 5, group_json.fetch("display_order")
    refute_includes group_json.keys, "user_id"
  end

  test "does not update another user's transaction tag group" do
    user = create(:user)
    other_user = create(:user)
    tag_group = create_tag_group(user: other_user, name: "Other", display_order: 1)
    raw_token = issue_token(user)

    patch api_v1_transaction_tag_group_path(tag_group),
      params: { transaction_tag_group: { name: "Changed" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :not_found
    assert_equal "Other", tag_group.reload.name
  end

  test "deletes a transaction tag group for the token owner" do
    user = create(:user)
    tag_group = create_tag_group(user: user, name: "Bills", display_order: 1)
    raw_token = issue_token(user)

    delete api_v1_transaction_tag_group_path(tag_group), headers: json_headers(raw_token)

    assert_response :no_content
    assert_empty response.body
    assert_predicate tag_group.reload, :discarded?
  end

  test "deletes transaction tags with their tag group" do
    user = create(:user)
    other_user = create(:user)
    tag_group = create_tag_group(user: user, name: "Bills", display_order: 1)
    tag = TransactionTag.create!(user: user, transaction_tag_group: tag_group, name: "Rent", display_order: 1)
    other_tag_group = create_tag_group(user: other_user, name: "Other Bills", display_order: 1)
    other_tag = TransactionTag.create!(user: other_user, transaction_tag_group: other_tag_group, name: "Other Rent", display_order: 1)
    raw_token = issue_token(user)

    delete api_v1_transaction_tag_group_path(tag_group), headers: json_headers(raw_token)

    assert_response :no_content
    assert_predicate tag_group.reload, :discarded?
    assert_predicate tag.reload, :discarded?
    assert_predicate other_tag_group.reload, :kept?
    assert_predicate other_tag.reload, :kept?
  end

  test "does not delete another user's transaction tag group" do
    user = create(:user)
    other_user = create(:user)
    tag_group = create_tag_group(user: other_user, name: "Other", display_order: 1)
    raw_token = issue_token(user)

    delete api_v1_transaction_tag_group_path(tag_group), headers: json_headers(raw_token)

    assert_response :not_found
    refute_predicate tag_group.reload, :discarded?
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
end
