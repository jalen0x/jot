require "test_helper"

class ApiV1InsightExplorersTest < ActionDispatch::IntegrationTest
  test "lists only the token owner's kept insight explorers" do
    user = create(:user)
    other_user = create(:user)
    later = create_explorer(user: user, name: "Later", display_order: 2, config: { "chart" => "line" })
    earlier = create_explorer(user: user, name: "Earlier", display_order: 1, config: { "chart" => "bar" })
    discarded = create_explorer(user: user, name: "Discarded", display_order: 3)
    discarded.discard!
    create_explorer(user: other_user, name: "Other", display_order: 1)
    raw_token = issue_token(user)

    get api_v1_insight_explorers_path, headers: json_headers(raw_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "insight_explorers" ], body.keys
    explorers = body.fetch("insight_explorers")
    assert_equal [ earlier.to_param, later.to_param ], explorers.map { |item| item.fetch("id") }
    assert_equal [ "Earlier", "Later" ], explorers.map { |item| item.fetch("name") }
    assert_equal({ "chart" => "bar" }, explorers.first.fetch("config"))
    refute_includes explorers.first.keys, "user_id"
  end

  test "shows one insight explorer for the token owner" do
    user = create(:user)
    explorer = create_explorer(user: user, name: "Monthly spend", display_order: 1, config: { "chart" => "bar" }, hidden: true)
    raw_token = issue_token(user)

    get api_v1_insight_explorer_path(explorer), headers: json_headers(raw_token)

    assert_response :success
    explorer_json = JSON.parse(response.body).fetch("insight_explorer")
    assert_equal explorer.to_param, explorer_json.fetch("id")
    assert_equal "Monthly spend", explorer_json.fetch("name")
    assert_equal 1, explorer_json.fetch("display_order")
    assert_equal true, explorer_json.fetch("hidden")
    assert_equal({ "chart" => "bar" }, explorer_json.fetch("config"))
    refute_includes explorer_json.keys, "user_id"
  end

  test "does not show another user's insight explorer" do
    user = create(:user)
    explorer = create_explorer(user: create(:user), name: "Other", display_order: 1)
    raw_token = issue_token(user)

    get api_v1_insight_explorer_path(explorer), headers: json_headers(raw_token)

    assert_response :not_found
  end

  test "creates an insight explorer for the token owner" do
    user = create(:user)
    create_explorer(user: user, name: "Existing", display_order: 1)
    raw_token = issue_token(user)

    post api_v1_insight_explorers_path,
      params: { insight_explorer: { name: "  Monthly spend  ", config: { chart: "bar", filters: { kind: "expense" } }, hidden: "true" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :created
    explorer = user.insight_explorers.kept.where(name: "Monthly spend").sole
    assert_equal 2, explorer.display_order
    assert_equal true, explorer.hidden
    assert_equal({ "chart" => "bar", "filters" => { "kind" => "expense" } }, explorer.config)

    explorer_json = JSON.parse(response.body).fetch("insight_explorer")
    assert_equal explorer.to_param, explorer_json.fetch("id")
    assert_equal "Monthly spend", explorer_json.fetch("name")
    assert_equal 2, explorer_json.fetch("display_order")
    assert_equal true, explorer_json.fetch("hidden")
  end

  test "updates an insight explorer for the token owner" do
    user = create(:user)
    explorer = create_explorer(user: user, name: "Monthly spend", display_order: 1)
    raw_token = issue_token(user)

    patch api_v1_insight_explorer_path(explorer),
      params: { insight_explorer: { name: "Yearly income", config: { chart: "line" }, hidden: "true", display_order: "7" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :success
    explorer.reload
    assert_equal "Yearly income", explorer.name
    assert_equal({ "chart" => "line" }, explorer.config)
    assert_equal true, explorer.hidden
    assert_equal 7, explorer.display_order

    explorer_json = JSON.parse(response.body).fetch("insight_explorer")
    assert_equal "Yearly income", explorer_json.fetch("name")
    assert_equal 7, explorer_json.fetch("display_order")
  end

  test "rejects invalid insight explorer params" do
    user = create(:user)
    raw_token = issue_token(user)

    post api_v1_insight_explorers_path,
      params: { insight_explorer: { name: "", config: { chart: "bar" }, hidden: "false" } },
      headers: json_headers(raw_token),
      as: :json

    assert_response :unprocessable_content
    assert_empty user.insight_explorers
    assert_match(/Name/i, response.body)
  end

  test "deletes an insight explorer for the token owner" do
    user = create(:user)
    explorer = create_explorer(user: user, name: "Monthly spend", display_order: 1)
    raw_token = issue_token(user)

    delete api_v1_insight_explorer_path(explorer), headers: json_headers(raw_token)

    assert_response :no_content
    assert_empty response.body
    assert_predicate explorer.reload, :discarded?
  end

  test "does not delete another user's insight explorer" do
    user = create(:user)
    explorer = create_explorer(user: create(:user), name: "Other", display_order: 1)
    raw_token = issue_token(user)

    delete api_v1_insight_explorer_path(explorer), headers: json_headers(raw_token)

    assert_response :not_found
    assert_predicate explorer.reload, :kept?
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

  def create_explorer(user:, name:, display_order:, config: {}, hidden: false)
    InsightExplorer.create!(user: user, name: name, display_order: display_order, config: config, hidden: hidden)
  end
end
