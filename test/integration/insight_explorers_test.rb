require "test_helper"

class InsightExplorersTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get insight_explorers_path

    assert_redirected_to new_user_session_path
  end

  test "lists only the signed-in user's kept insight explorers" do
    user = create(:user)
    other_user = create(:user)
    earlier = create_explorer(user: user, name: "Earlier", display_order: 1, config: { "chart" => "bar" })
    later = create_explorer(user: user, name: "Later", display_order: 2)
    discarded = create_explorer(user: user, name: "Discarded", display_order: 3)
    discarded.discard!
    create_explorer(user: other_user, name: "Other", display_order: 1)
    sign_in user

    get insight_explorers_path

    assert_response :success
    assert_match "Earlier", response.body
    assert_match "Later", response.body
    refute_match "Discarded", response.body
    refute_match "Other", response.body
    assert_select "a[href='#{edit_insight_explorer_path(earlier)}']", text: /Edit/i
    assert_select "form[action='#{insight_explorer_path(later)}'][data-turbo-confirm]"
  end

  test "creates an insight explorer from JSON config params" do
    user = create(:user)
    create_explorer(user: user, name: "Existing", display_order: 1)
    sign_in user

    post insight_explorers_path, params: {
      insight_explorer: {
        name: "  Monthly spend  ",
        hidden: "1",
        config_json: '{"chart":"bar","filters":{"kind":"expense"}}'
      }
    }

    assert_redirected_to insight_explorers_path
    explorer = user.insight_explorers.kept.where(name: "Monthly spend").sole
    assert_equal 2, explorer.display_order
    assert_equal true, explorer.hidden
    assert_equal({ "chart" => "bar", "filters" => { "kind" => "expense" } }, explorer.config)
  end

  test "rejects invalid JSON config params" do
    user = create(:user)
    sign_in user

    post insight_explorers_path, params: {
      insight_explorer: {
        name: "Broken config",
        hidden: "0",
        config_json: "{not json"
      }
    }

    assert_response :unprocessable_content
    assert_empty user.insight_explorers.kept
    assert_match(/Config JSON is invalid/i, response.body)
  end

  test "edits and updates the signed-in user's insight explorer" do
    user = create(:user)
    explorer = create_explorer(user: user, name: "Monthly spend", display_order: 1, config: { "chart" => "bar" })
    sign_in user

    get edit_insight_explorer_path(explorer)

    assert_response :success
    assert_match "Monthly spend", response.body

    patch insight_explorer_path(explorer), params: {
      insight_explorer: {
        name: "Yearly income",
        display_order: "7",
        hidden: "1",
        config_json: '{"chart":"line"}'
      }
    }

    assert_redirected_to insight_explorers_path
    explorer.reload
    assert_equal "Yearly income", explorer.name
    assert_equal 7, explorer.display_order
    assert_equal true, explorer.hidden
    assert_equal({ "chart" => "line" }, explorer.config)
  end

  test "does not update another user's insight explorer" do
    user = create(:user)
    explorer = create_explorer(user: create(:user), name: "Other", display_order: 1, config: { "chart" => "bar" })
    sign_in user

    patch insight_explorer_path(explorer), params: {
      insight_explorer: {
        name: "Changed",
        display_order: "2",
        hidden: "1",
        config_json: '{"chart":"line"}'
      }
    }

    assert_response :not_found
    assert_equal "Other", explorer.reload.name
    assert_equal({ "chart" => "bar" }, explorer.config)
  end

  test "destroys only the signed-in user's insight explorer" do
    user = create(:user)
    explorer = create_explorer(user: user, name: "Monthly spend", display_order: 1)
    other_explorer = create_explorer(user: create(:user), name: "Other", display_order: 1)
    sign_in user

    delete insight_explorer_path(explorer)

    assert_response :see_other
    assert_redirected_to insight_explorers_path
    assert_predicate explorer.reload, :discarded?
    assert_predicate other_explorer.reload, :kept?
  end

  private

  def create_explorer(user:, name:, display_order:, config: {}, hidden: false)
    InsightExplorer.create!(user: user, name: name, display_order: display_order, config: config, hidden: hidden)
  end
end
