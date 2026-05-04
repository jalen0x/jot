require "test_helper"

class InsightExplorerTest < ActiveSupport::TestCase
  test "stores bounded JSON config for a user" do
    explorer = InsightExplorer.new(
      user: create(:user),
      name: "  Monthly spend  ",
      config: { "chart" => "bar", "filters" => { "kind" => "expense" } },
      display_order: 1
    )

    assert_predicate explorer, :valid?, explorer.errors.full_messages.to_sentence
    assert_equal "Monthly spend", explorer.name
    assert_equal({ "chart" => "bar", "filters" => { "kind" => "expense" } }, explorer.config)
  end

  test "requires a name" do
    explorer = InsightExplorer.new(user: create(:user), name: "", config: {}, display_order: 1)

    refute_predicate explorer, :valid?
    assert_includes explorer.errors[:name], "can't be blank"
  end

  test "requires config to be a JSON object" do
    explorer = InsightExplorer.new(user: create(:user), name: "Invalid", config: [ "not", "object" ], display_order: 1)

    refute_predicate explorer, :valid?
    assert_includes explorer.errors[:config], "must be a JSON object"
  end

  test "limits config size" do
    explorer = InsightExplorer.new(user: create(:user), name: "Too large", config: { "payload" => "x" * 33.kilobytes }, display_order: 1)

    refute_predicate explorer, :valid?
    assert_includes explorer.errors[:config], "is too large"
  end

  test "serializes the public API shape" do
    explorer = InsightExplorer.create!(
      user: create(:user),
      name: "Monthly spend",
      config: { "chart" => "bar" },
      display_order: 2,
      hidden: true
    )

    explorer_json = explorer.as_json
    assert_equal [ :id, :name, :display_order, :hidden, :config ], explorer_json.keys
    assert_equal explorer.to_param, explorer_json.fetch(:id)
    assert_equal "Monthly spend", explorer_json.fetch(:name)
    assert_equal 2, explorer_json.fetch(:display_order)
    assert_equal true, explorer_json.fetch(:hidden)
    assert_equal({ "chart" => "bar" }, explorer_json.fetch(:config))
  end
end
